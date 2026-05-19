import gzip
import hashlib
import json
import logging
import os
import threading
import time
from concurrent.futures import Future, ThreadPoolExecutor, TimeoutError
from typing import Any

import requests
from flask import Flask, Response, g, request

try:
    import orjson  # type: ignore
except ImportError:  # pragma: no cover - optional dependency
    orjson = None

try:
    from pyngrok import ngrok  # type: ignore
except ImportError:  # pragma: no cover - optional dependency
    ngrok = None

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = int(os.getenv("MAX_REQUEST_BYTES", "32768"))

# Core runtime config
HOST = os.getenv("BACKEND_HOST", "0.0.0.0")
PORT = int(os.getenv("BACKEND_PORT", "5001"))
MODEL = os.getenv("OLLAMA_MODEL", "llama3")
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
MODEL_KEEP_ALIVE = os.getenv("OLLAMA_KEEP_ALIVE", "15m")
MODEL_TIMEOUT_SECONDS = float(os.getenv("OLLAMA_TIMEOUT_SECONDS", "20"))
INFERENCE_WORKERS = max(1, int(os.getenv("OLLAMA_MAX_PARALLEL", "1")))
WARM_MODEL_ON_START = os.getenv("WARM_MODEL_ON_START", "true").lower() == "true"

# Cache config
CACHE_TTL_SECONDS = int(os.getenv("INSIGHTS_CACHE_TTL", "300"))
CACHE_MAX_ITEMS = int(os.getenv("INSIGHTS_CACHE_MAX_ITEMS", "512"))

# Response shaping
# One field per screen: home_digest (Home), summary (Month Summary),
# category_highlight (Category Breakdown), subs_and_bills (Subs & Bills),
# goal_insight (Goals).  Swift callers pass fields=["summary"] etc. to get
# only what their screen needs; the cache key includes the field list so a
# Goals-only call never waits on a full Home call.
ALLOWED_FIELDS = ("home_digest", "summary", "category_highlight", "subs_and_bills", "goal_insight")
GZIP_MIN_BYTES = int(os.getenv("GZIP_MIN_BYTES", "256"))

# Public URL / ngrok
PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "")
AUTO_START_NGROK = os.getenv("AUTO_START_NGROK", "false").lower() == "true"
NGROK_AUTHTOKEN = os.getenv("NGROK_AUTHTOKEN")
NGROK_DOMAIN = os.getenv("NGROK_DOMAIN")

logger = logging.getLogger("mint-backend")
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s %(levelname)s %(message)s",
)

session = requests.Session()
session.headers.update({"Connection": "keep-alive", "Content-Type": "application/json"})
session.mount("http://", requests.adapters.HTTPAdapter(pool_connections=16, pool_maxsize=16, max_retries=0))
session.mount("https://", requests.adapters.HTTPAdapter(pool_connections=16, pool_maxsize=16, max_retries=0))

executor = ThreadPoolExecutor(max_workers=INFERENCE_WORKERS, thread_name_prefix="ollama")
cache_lock = threading.Lock()
inflight_lock = threading.Lock()
metrics_lock = threading.Lock()

cache: dict[str, dict[str, Any]] = {}
inflight: dict[str, Future] = {}
metrics = {
    "requests_total": 0,
    "cache_hits": 0,
    "cache_misses": 0,
    "inflight_waits": 0,
    "model_calls": 0,
    "model_failures": 0,
    "avg_request_ms": 0.0,
    "avg_model_ms": 0.0,
}
last_model_error: str | None = None
last_model_success_at: float | None = None


def now_ms() -> float:
    return time.perf_counter() * 1000.0


def json_dumps(payload: Any) -> bytes:
    if orjson is not None:
        return orjson.dumps(payload)
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def json_response(payload: Any, status: int = 200) -> Response:
    return Response(json_dumps(payload), status=status, mimetype="application/json")


def html_response(html: str, status: int = 200) -> Response:
    return Response(html, status=status, mimetype="text/html")


def canonical_json(payload: Any) -> str:
    if orjson is not None:
        return orjson.dumps(payload, option=orjson.OPT_SORT_KEYS).decode("utf-8")
    return json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def payload_hash(payload: dict[str, Any], fields: list[str]) -> str:
    raw = canonical_json({"payload": payload, "fields": fields})
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def prune_cache_if_needed() -> None:
    with cache_lock:
        if len(cache) <= CACHE_MAX_ITEMS:
            return

        current_time = time.time()
        expired_keys = [key for key, value in cache.items() if value["expires_at"] <= current_time]
        for key in expired_keys:
            cache.pop(key, None)

        if len(cache) <= CACHE_MAX_ITEMS:
            return

        oldest_keys = sorted(cache.items(), key=lambda item: item[1]["expires_at"])[: len(cache) - CACHE_MAX_ITEMS]
        for key, _ in oldest_keys:
            cache.pop(key, None)


def get_cached(cache_key: str) -> dict[str, Any] | None:
    with cache_lock:
        item = cache.get(cache_key)
        if not item:
            return None
        if item["expires_at"] <= time.time():
            cache.pop(cache_key, None)
            return None
        return item["value"]


def set_cached(cache_key: str, payload: dict[str, Any]) -> None:
    with cache_lock:
        cache[cache_key] = {
            "value": payload,
            "expires_at": time.time() + CACHE_TTL_SECONDS,
        }
    prune_cache_if_needed()


def update_metric(key: str, value: float | int = 1) -> None:
    with metrics_lock:
        metrics[key] = metrics.get(key, 0) + value


def update_running_average(key: str, sample_ms: float, count_key: str) -> None:
    with metrics_lock:
        count = max(1, int(metrics.get(count_key, 0)))
        current = float(metrics.get(key, 0.0))
        metrics[key] = current + ((sample_ms - current) / count)


def normalize_fields(raw_fields: Any) -> list[str]:
    if not isinstance(raw_fields, list):
        return list(ALLOWED_FIELDS)

    filtered_fields = [field for field in raw_fields if field in ALLOWED_FIELDS]
    return filtered_fields or list(ALLOWED_FIELDS)


def normalize_payload(body: dict[str, Any]) -> tuple[dict[str, Any], list[str], bool]:
    raw_payload = body.get("payload") if isinstance(body.get("payload"), dict) else body
    payload = {
        "summary":      raw_payload.get("summary") or {},
        "category":     raw_payload.get("category") or {},
        "subs_and_bills": raw_payload.get("subs_and_bills") or raw_payload.get("subsAndBills") or {},
        # Goals: list of {name, target, saved, monthly_contribution, deadline_months?}
        # Populated by Goals screen; absent on other screens — that's fine, the
        # goal_insight field simply returns "" when this list is empty.
        "goals": raw_payload.get("goals") if isinstance(raw_payload.get("goals"), list) else [],
    }
    fields = normalize_fields(body.get("fields"))
    force_refresh = bool(body.get("force_refresh", False))
    return payload, fields, force_refresh


def filter_response_fields(payload: dict[str, str], fields: list[str]) -> dict[str, str]:
    return {field: payload.get(field, "") for field in fields}


def has_meaningful_data(payload: dict[str, Any], fields: list[str]) -> bool:
    summary      = payload.get("summary", {})
    category     = payload.get("category", {})
    subs         = payload.get("subs_and_bills", {})
    goals        = payload.get("goals", [])

    checks = {
        "home_digest":       (
            float(summary.get("total_expense") or 0) > 0
            or int(subs.get("unpaid_bills_count") or 0) > 0
        ),
        "summary":           float(summary.get("total_expense") or 0) > 0 or float(summary.get("total_income") or 0) > 0,
        "category_highlight": float(category.get("total_expense") or 0) > 0 and bool(category.get("top_categories")),
        "subs_and_bills":    (
            int(subs.get("unpaid_bills_count") or 0) > 0
            or int(subs.get("active_subscription_count") or 0) > 0
        ),
        "goal_insight":      isinstance(goals, list) and len(goals) > 0,
    }
    return any(checks.get(field, False) for field in fields)


def format_rupees(value: Any) -> str:
    try:
        amount = float(value or 0)
    except (TypeError, ValueError):
        amount = 0.0

    if abs(amount - round(amount)) < 0.01:
        return f"₹{amount:,.0f}"
    return f"₹{amount:,.2f}"


def clean_sentence(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    cleaned = " ".join(value.replace("\n", " ").split()).strip()
    if not cleaned:
        return ""
    lowered = cleaned.lower()
    if lowered.startswith(("could not", "n/a", "none", "null", "no insight")):
        return ""
    return cleaned


def empty_insights(fields: list[str]) -> dict[str, str]:
    return {field: "" for field in fields}


def is_low_value_insight(text: str) -> bool:
    """
    Reject sentences that just restate a number already visible on screen.
    The model is instructed not to produce these, but this is a safety net.
    """
    lowered = text.lower()

    # Raw data regurgitation (chart/card already shows these)
    obvious_markers = (
        "spend is ",
        "spending is ",
        "spending stands at ",
        "peaked on day ",
        "leads spending at ",
        "upcoming unpaid bills currently add up to ",
        "active subscriptions total ",
        "your total expense",
        "you have spent",
        "you spent a total",
        "total spending for",
        "goal is % complete",
        "you have saved",
        "subscriptions cost",
        "bills total",
    )
    if any(marker in lowered for marker in obvious_markers):
        return True

    # Due-date announcements with no action attached
    due_markers = (" is due today.", " is due tomorrow.", " is due in ")
    if any(m in lowered for m in due_markers) and "set aside" not in lowered and "plan" not in lowered and "transfer" not in lowered:
        return True

    return False


# ── Per-field prompt instructions ─────────────────────────────────────────────
# Each entry maps the insight field name to:
#   • which screen it appears on
#   • what data to draw from (model already has all sections)
#   • what NOT to write (already on-screen)
#   • the behavioural science lens to apply
#   • tone guidance

_FIELD_INSTRUCTIONS: dict[str, str] = {

    "home_digest": (
        "Screen: Home (user just launched the app — this is the first thing they read).\n"
        "Behavioural lens: peak-end rule — the first impression sets the tone for the session.\n"
        "Priority: identify the SINGLE most urgent or interesting signal across ALL sections:\n"
        "  (1) Budget pace risk: if __derived.projection_vs_budget > 0, name the projected overspend as ₹X "
        "and suggest one lever (e.g. 'cutting dining by ₹200/day closes the gap').\n"
        "  (2) Bill within 3 days: warn concisely ('₹X due in N days — move funds now').\n"
        "  (3) Unusual category spike: if any category share_percent > 40%, flag it with a habit angle.\n"
        "  (4) Goal almost done: if any goal completion_pct >= 90, celebrate it.\n"
        "Pick whichever of (1)–(4) applies first. Write ONE sentence. Never combine two signals.\n"
        "Do NOT mention the total spent or income — those are prominent on the home screen already.\n"
        "Tone: alert but calm. No alarm words ('warning', 'danger', 'problem')."
    ),

    "summary": (
        "Screen: Month Summary (user reviewing whole-month progress).\n"
        "Behavioural lens: implementation intentions — give them a specific 'if-then' plan.\n"
        "Use __derived.projection_vs_budget to decide which branch to write:\n"
        "  If projection_vs_budget <= 0 (on track): acknowledge the pace briefly, then add one "
        "habit-reinforcing observation (e.g. 'your daily average is ₹X lower than last month — "
        "that difference compounds').\n"
        "  If projection_vs_budget > 0 (at risk): state the projected overspend as a ₹ figure, "
        "then name one specific category or behaviour lever to close the gap. Make the action "
        "concrete ('skipping two restaurant visits saves ~₹600').\n"
        "Use previous_month_average vs daily_average for acceleration/improvement comparisons.\n"
        "Do NOT restate current total, days elapsed, or income — those fill the summary cards.\n"
        "Tone: coaching, forward-looking, never alarming."
    ),

    "category_highlight": (
        "Screen: Category Breakdown (user looking at their spending by category).\n"
        "Behavioural lens: category budgeting psychology — people underestimate 'lifestyle creep' "
        "in small-frequent categories.\n"
        "Write ONE non-obvious behavioral observation. Strong options:\n"
        "  • Two categories that together reveal a pattern (high dining + high transport = "
        "frequent out-of-home activity — offer one tweak).\n"
        "  • A category that is accelerating: if the top category share_percent > 35%, "
        "note it's dominating the budget and suggest a weekly ceiling.\n"
        "  • Opportunity re-frame: 'Your ₹X on [category] this month = N months of [goal] contributions.'\n"
        "NEVER name the top category alone with no insight — that's on the chart already.\n"
        "NEVER quote amounts that are already labeled on the pie slices.\n"
        "Add a habit-loop suggestion: one small rule the user could try this week.\n"
        "Tone: observational and curious, not prescriptive."
    ),

    "subs_and_bills": (
        "Screen: Subscriptions & Bills (user reviewing recurring payments).\n"
        "Behavioural lens: status quo bias — people forget subscriptions exist; naming them "
        "makes inaction feel like a deliberate choice.\n"
        "Priority (pick the strongest signal):\n"
        "  (1) Urgent: days_until_next_bill <= 3 → warn about the specific bill, name the ₹ amount, "
        "suggest transferring now. Add any upcoming bills that cluster in the same week.\n"
        "  (2) Burden: if subscription_burden_pct_of_income > 8%, flag the percentage and "
        "invite a review ('your subs eat N% of income — one review session could free ₹X/month').\n"
        "  (3) Opportunity cost: frame monthly_subscription_total annually "
        "('₹X/month = ₹Y/year — worth auditing once a quarter').\n"
        "NEVER restate the count of bills or subscriptions — the list is right there.\n"
        "Tone: helpful and practical. Frame as 'worth checking' not a command."
    ),

    "goal_insight": (
        "Screen: Goals (user reviewing savings goals).\n"
        "Behavioural lens: goal gradient effect — effort increases as people approach a finish line; "
        "make the nearest goal feel close.\n"
        "Use the pre-sorted goals list (index 0 = highest completion_pct).\n"
        "Branch:\n"
        "  • If goals[0].completion_pct >= 90: celebrate it by name and pivot to the next goal "
        "('Almost there — then you can focus on [next goal]').\n"
        "  • If goals[0].completion_pct >= 50: use months_remaining_at_current_rate to show "
        "proximity ('N months at your current pace — you're in the home stretch').\n"
        "  • If all goals completion_pct < 25: it's early. Offer one 'what if' scenario: "
        "'Adding ₹X more per month shaves N months off [goal name].' Use monthly_contribution "
        "from the data to ground the number.\n"
        "Never list all goals or all amounts — the user can see the list.\n"
        "Never say 'you have saved ₹X' — the progress bar already shows that.\n"
        "Tone: motivating, progress-focused, warm."
    ),
}


def build_prompt(payload: dict[str, Any], fields: list[str]) -> str:
    """
    Construct a screen-aware, behaviourally-grounded prompt.
    All arithmetic is pre-computed in Python so the model only writes prose.
    """
    summary  = payload.get("summary", {})
    category = payload.get("category", {})
    subs     = payload.get("subs_and_bills", {})
    goals    = payload.get("goals", [])

    # ── Pre-compute derived metrics ──────────────────────────────────────────
    days_elapsed   = max(1, int(summary.get("days_elapsed") or 1))
    days_in_month  = max(1, int(summary.get("days_in_month") or 30))
    total_expense  = float(summary.get("total_expense") or 0)
    budget         = float(summary.get("budget") or 0)
    monthly_income = float(summary.get("total_income") or 0)

    daily_avg        = total_expense / days_elapsed
    projected_total  = round(daily_avg * days_in_month)
    budget_remaining = round(budget - total_expense) if budget else None
    proj_vs_budget   = round(projected_total - budget) if budget else None

    sub_total        = float(subs.get("monthly_subscription_total") or 0)
    sub_burden_pct   = round(100 * sub_total / monthly_income) if monthly_income else None

    # Enrich goal list and sort by completion so the model can use index 0
    goals_enriched: list[dict[str, Any]] = []
    for g in (goals if isinstance(goals, list) else []):
        target  = float(g.get("target") or 0)
        saved   = float(g.get("saved") or 0)
        monthly = float(g.get("monthly_contribution") or 0)
        pct     = int(100 * saved / max(1.0, target))
        remaining_amt = max(0.0, target - saved)
        months_left   = int(remaining_amt / max(1.0, monthly)) if monthly else None
        goals_enriched.append({
            "name":                          g.get("name", "Goal"),
            "target":                        format_rupees(target),
            "saved":                         format_rupees(saved),
            "monthly_contribution":          format_rupees(monthly),
            "completion_pct":               pct,
            "remaining":                    format_rupees(remaining_amt),
            "months_remaining_at_current_rate": months_left,
        })
    goals_enriched.sort(key=lambda g: g["completion_pct"], reverse=True)

    # ── Compact data block (model reads this as ground truth) ────────────────
    compact_data: dict[str, Any] = {
        "summary": {
            "month_name":              summary.get("month_name"),
            "year":                    summary.get("year"),
            "days_elapsed":            days_elapsed,
            "days_in_month":           days_in_month,
            "total_expense":           format_rupees(total_expense),
            "total_income":            format_rupees(monthly_income),
            "budget":                  format_rupees(budget) if budget else None,
            "daily_average":           format_rupees(daily_avg),
            "previous_month_average":  format_rupees(float(summary.get("previous_month_average") or 0)),
            "highest_spend_day":       summary.get("highest_spend_day"),
            "highest_spend_day_amount": format_rupees(float(summary.get("highest_spend_day_amount") or 0)),
            "__derived": {
                "projected_monthly_total": format_rupees(projected_total),
                "budget_remaining":        format_rupees(budget_remaining) if budget_remaining is not None else None,
                "projection_vs_budget":    format_rupees(proj_vs_budget) if proj_vs_budget is not None else None,
            },
        },
        "category": {
            "total_expense":   format_rupees(float(category.get("total_expense") or 0)),
            "category_count":  category.get("category_count"),
            "top_categories":  [
                {
                    "name":          cat.get("name"),
                    "amount":        format_rupees(float(cat.get("amount") or 0)),
                    "share_percent": cat.get("share_percent"),
                    "budget":        format_rupees(float(cat.get("budget") or 0)) if cat.get("budget") else None,
                    "budget_used_pct": (
                        int(100 * float(cat.get("amount") or 0) / float(cat.get("budget") or 1))
                        if cat.get("budget") else None
                    ),
                }
                for cat in (category.get("top_categories") or [])
            ],
        },
        "subs_and_bills": {
            "unpaid_bills_count":         subs.get("unpaid_bills_count"),
            "upcoming_bills_total":       format_rupees(float(subs.get("upcoming_bills_total") or 0)),
            "next_bill_name":             subs.get("next_bill_name"),
            "next_bill_amount":           format_rupees(float(subs.get("next_bill_amount") or 0)),
            "next_bill_due_date":         subs.get("next_bill_due_date"),
            "days_until_next_bill":       subs.get("days_until_next_bill"),
            "active_subscription_count":  subs.get("active_subscription_count"),
            "monthly_subscription_total": format_rupees(sub_total),
            "__derived": {
                "annual_subscription_cost":        format_rupees(sub_total * 12),
                "subscription_burden_pct_of_income": sub_burden_pct,
            },
        },
        "goals": goals_enriched,
    }

    # ── Per-field instructions block ─────────────────────────────────────────
    field_block = "\n\n".join(
        f"--- [{field}] ---\n{_FIELD_INSTRUCTIONS.get(field, 'Write one useful financial coaching sentence under 18 words.')}"
        for field in fields
    )

    requested_shape = {field: "" for field in fields}

    return (
        "You are a financial coaching AI writing short insight labels for a mobile expense-tracking app.\n"
        "Return ONLY a valid JSON object — no prose, no markdown, no explanation outside the JSON.\n\n"
        "Hard rules:\n"
        "  • Each key maps to exactly ONE sentence (≤18 words) or an empty string \"\".\n"
        "  • Use ₹ for every monetary value. Use ONLY numbers from the provided data — never invent figures.\n"
        "  • Do not restate anything already visible on-screen (totals, category names, list counts, "
        "progress bar values). The insight must add something the chart/list cannot show.\n"
        "  • Never shame, alarm, or use words like 'warning', 'danger', 'you failed'.\n"
        "  • If a field has no strong insight to offer, return \"\" — silence beats a generic observation.\n"
        "  • Never use these low-value phrases: 'your spending is', 'you have X bills', "
        "'leading category is', 'you have saved', 'subscriptions cost', 'total spending for'.\n\n"
        f"Per-field instructions — read carefully before writing each value:\n\n{field_block}\n\n"
        f"Return this exact JSON shape (no extra keys):\n{canonical_json(requested_shape)}\n\n"
        f"Financial data (all arithmetic pre-computed — trust __derived values):\n{canonical_json(compact_data)}"
    )

VALID_TRIGGERS = frozenset({"overspend", "post_purchase", "goal_update", "subscription_audit", "habit_builder"})

_NUDGE_PRINCIPLES: dict[str, str] = {
    "overspend":           "loss aversion",
    "post_purchase":       "post-purchase reflection",
    "goal_update":         "goal gradient effect",
    "subscription_audit":  "opportunity cost",
    "habit_builder":       "small wins / habit loop",
}


def _nudge_profile_str(profile: dict[str, Any]) -> str:
    income      = format_rupees(profile.get("monthly_income", 0))
    stage       = profile.get("career_stage", "early")         # early | mid | senior
    personality = profile.get("spending_personality", "steady") # impulse | steady | saver
    city        = profile.get("city", "")
    city_str    = f", based in {city}" if city else ""
    return f"monthly income {income}, {stage}-career, {personality} spender{city_str}"


def build_nudge_prompt(trigger: str, profile: dict[str, Any], ctx: dict[str, Any]) -> str:
    """
    Build a screen-aware, behaviourally-grounded single-sentence nudge prompt.
    All arithmetic is pre-computed here; the model only writes prose.

    ctx keys per trigger
    ────────────────────
    overspend:          category, spent, budget, goal_name,
                        days_left_in_month (optional)
    post_purchase:      last_purchase_amount, last_purchase_category,
                        goal_name, goal_saved, goal_target (optional)
    goal_update:        goal_name, goal_target, goal_saved,
                        monthly_contribution (optional)
    subscription_audit: subscription_name, subscription_monthly,
                        months_since_last_used (optional),
                        opportunity_label (optional, e.g. 'a weekend in Goa')
    habit_builder:      week_number, week_savings, challenge_name,
                        streak_weeks (optional)
    """
    principle   = _NUDGE_PRINCIPLES.get(trigger, "behavioural nudge")
    profile_str = _nudge_profile_str(profile)

    # ── Shared header ────────────────────────────────────────────────────────
    base = (
        "You are a behavioural-finance coach writing a single push-notification–style nudge\n"
        "for a mobile expense-tracking app.\n\n"
        f"Behavioural principle: {principle}.\n"
        f"User profile: {profile_str}.\n\n"
        "Hard rules:\n"
        "  • Exactly ONE sentence. Maximum 22 words.\n"
        "  • Use ₹ for all money. Use only numbers from the provided data.\n"
        "  • Be specific — name the category, goal, or subscription by its actual name.\n"
        "  • No shaming. No alarm words ('danger', 'you failed', 'terrible').\n"
        "  • Tone: warm coach, not disappointed parent.\n"
        '  • Return ONLY valid JSON: {"nudge": "<sentence>", "principle": "<2-3 word label>"}\n\n'
    )

    # ── Trigger-specific blocks ───────────────────────────────────────────────
    if trigger == "overspend":
        # Appears on: Category Breakdown screen + Home screen
        # Lens: loss aversion — connect the overspend to a real goal the user cares about
        category = ctx.get("category", "this category")
        goal     = ctx.get("goal_name", "your goal")
        days_left = int(ctx.get("days_left_in_month", 0))
        try:
            spent  = float(ctx.get("spent", 0))
            budget = float(ctx.get("budget", 0))
            overage = max(0.0, spent - budget)
            pct_over = int(100 * overage / max(1.0, budget))
        except (TypeError, ValueError):
            overage = 0.0
            pct_over = 0
        data = (
            f"Category: {category}. "
            f"Spent: {format_rupees(ctx.get('spent', 0))}. "
            f"Budget: {format_rupees(ctx.get('budget', 0))}. "
            f"Overage: {format_rupees(overage)} ({pct_over}% over). "
            f"Goal at risk: {goal}. "
            f"Days left in month: {days_left}."
        )
        instruction = (
            "Frame using loss aversion: connect the specific ₹ overage to real progress lost on the named goal.\n"
            "If days_left > 0, mention how many days remain to course-correct.\n"
            "Example pattern: '[Overage] more on [category] means [goal] slips by [N weeks/₹X].'\n"
            "Do NOT just say 'you overspent' — make the cost feel tangible."
        )

    elif trigger == "post_purchase":
        # Appears on: Category Breakdown screen + Goals screen
        # Lens: post-purchase reflection — build awareness without triggering buyer's remorse
        amount   = format_rupees(ctx.get("last_purchase_amount", 0))
        category = ctx.get("last_purchase_category", "this purchase")
        goal     = ctx.get("goal_name", "your savings goal")
        try:
            goal_saved  = float(ctx.get("goal_saved", 0))
            goal_target = float(ctx.get("goal_target", 0))
            goal_pct    = int(100 * goal_saved / max(1.0, goal_target))
            purchase_as_goal_days = 0
            monthly_contrib = float(ctx.get("monthly_contribution") or 0)
            if monthly_contrib > 0:
                purchase_amt = float(ctx.get("last_purchase_amount", 0))
                purchase_as_goal_days = round(purchase_amt / (monthly_contrib / 30))
        except (TypeError, ValueError, ZeroDivisionError):
            goal_pct = 0
            purchase_as_goal_days = 0
        data = (
            f"Purchase: {amount} on {category}. "
            f"Goal: {goal} ({goal_pct}% complete). "
            + (f"This purchase = approx {purchase_as_goal_days} days of {goal} contributions." if purchase_as_goal_days else "")
        )
        instruction = (
            "Write a gentle reflection that creates awareness without guilt.\n"
            "If purchase_as_goal_days > 0, anchor the spend to goal progress lost/maintained.\n"
            "Frame as curiosity, not judgement: 'That ₹X on [category] is [N] days of [goal] progress — "
            "intentional choice or habit?'\n"
            "Do NOT say the purchase was 'bad' or 'wrong'."
        )

    elif trigger == "goal_update":
        # Appears on: Goals screen
        # Lens: goal gradient — highlight proximity to finish, not distance
        goal    = ctx.get("goal_name", "your goal")
        try:
            target  = float(ctx.get("goal_target", 0))
            saved   = float(ctx.get("goal_saved", 0))
            monthly = float(ctx.get("monthly_contribution") or 0)
            pct     = int(100 * saved / max(1.0, target))
            remaining = max(0.0, target - saved)
            months_left = int(remaining / max(1.0, monthly)) if monthly else None
            # "What if" scenario: saving ₹X more/month
            extra_monthly = round(remaining / max(1, (months_left or 12) - 2)) if months_left and months_left > 2 else None
        except (TypeError, ValueError, ZeroDivisionError):
            pct = 0
            months_left = None
            remaining = 0.0
            extra_monthly = None
        data = (
            f"Goal: {goal}. "
            f"Target: {format_rupees(ctx.get('goal_target', 0))}. "
            f"Saved: {format_rupees(ctx.get('goal_saved', 0))} ({pct}%). "
            f"Remaining: {format_rupees(remaining)}. "
            f"Monthly contribution: {format_rupees(ctx.get('monthly_contribution', 0))}. "
            + (f"Months to finish at current rate: {months_left}. " if months_left else "")
            + (f"What-if: adding ₹{extra_monthly}/month finishes 2 months sooner." if extra_monthly else "")
        )
        instruction = (
            "Apply goal gradient — make the finish feel close, not the start far.\n"
            "Branch:\n"
            "  pct >= 90: celebrate by name, pivot to 'what's next'.\n"
            "  pct >= 50: use months_left to show proximity ('N months away — home stretch').\n"
            "  pct < 25 and what-if data present: offer the what-if scenario concretely.\n"
            "  pct < 25 and no what-if: acknowledge early progress, name one small win.\n"
            "Never say 'you have saved ₹X' — the progress bar already shows that."
        )

    elif trigger == "subscription_audit":
        # Appears on: Subs & Bills screen
        # Lens: opportunity cost — the annual figure triggers action better than the monthly one
        name          = ctx.get("subscription_name", "a subscription")
        unused_months = int(ctx.get("months_since_last_used", 0))
        opportunity   = ctx.get("opportunity_label", "")  # e.g. 'a weekend in Goa'
        try:
            monthly = float(ctx.get("subscription_monthly", 0))
            annual  = monthly * 12
        except (TypeError, ValueError):
            monthly = 0.0
            annual  = 0.0
        data = (
            f"Subscription: {name}. "
            f"Monthly: {format_rupees(monthly)}. "
            f"Annual cost: {format_rupees(annual)}. "
            + (f"Months since last used: {unused_months}. " if unused_months else "")
            + (f"Opportunity framing: {format_rupees(annual)} = {opportunity}. " if opportunity else "")
        )
        instruction = (
            "Apply opportunity cost framing — annual figure is more motivating than monthly.\n"
            "If months_since_last_used > 2, lead with 'unused for N months'.\n"
            "If opportunity_label is provided, use it: '₹X/year on [name] = [opportunity]'.\n"
            "Otherwise frame as: 'Worth a 2-minute audit — ₹X/year adds up.'\n"
            "Never command ('cancel it'). Frame as 'worth checking' or 'your call to make'."
        )

    elif trigger == "habit_builder":
        # Appears on: Home screen
        # Lens: small wins + habit loop — celebrate streaks, lower the bar to keep going
        week        = int(ctx.get("week_number", 1))
        challenge   = ctx.get("challenge_name", "no-spend challenge")
        streak      = int(ctx.get("streak_weeks", 0))
        savings     = format_rupees(ctx.get("week_savings", 0))
        data = (
            f"Week {week}. "
            f"Savings this week: {savings}. "
            f"Active challenge: {challenge}. "
            + (f"Current streak: {streak} weeks." if streak else "")
        )
        instruction = (
            "Apply small wins + habit loop.\n"
            "Celebrate the specific ₹ amount saved this week — make it feel like a real win.\n"
            "If streak >= 2, name the streak: 'N weeks running — the habit is forming.'\n"
            "If week == 1, focus on momentum: 'Week 1 done — the hardest part is starting.'\n"
            "End with a micro-commitment for next week (one sentence total).\n"
            "Tone: enthusiastic but not over-the-top. Warm coach, not cheerleader."
        )

    else:
        data        = canonical_json(ctx)
        instruction = "Write a helpful, specific financial nudge relevant to the user's current situation."

    return base + f"Data:\n{data}\n\nTask:\n{instruction}"


def normalize_generated_insights(generated: dict[str, str], fields: list[str]) -> dict[str, str]:
    normalized: dict[str, str] = {}
    for field in fields:
        text = clean_sentence(generated.get(field))
        normalized[field] = "" if is_low_value_insight(text) else text
    return normalized


# ── End nudge system ──────────────────────────────────────────────────────────

def parse_ollama_response(raw_text: str, fields: list[str]) -> dict[str, str]:
    try:
        parsed = json.loads(raw_text)
        if isinstance(parsed, dict):
            return {field: clean_sentence(parsed.get(field)) for field in fields}
    except Exception:
        pass

    start = raw_text.find("{")
    end = raw_text.rfind("}")
    if start != -1 and end > start:
        try:
            parsed = json.loads(raw_text[start : end + 1])
            if isinstance(parsed, dict):
                return {field: clean_sentence(parsed.get(field)) for field in fields}
        except Exception:
            return {field: "" for field in fields}

    return {field: "" for field in fields}


def call_ollama(payload: dict[str, Any], fields: list[str]) -> dict[str, str]:
    global last_model_error, last_model_success_at
    prompt = build_prompt(payload, fields)
    request_body = {
        "model": MODEL,
        "prompt": prompt,
        "stream": False,
        "format": "json",
        "keep_alive": MODEL_KEEP_ALIVE,
        "options": {
            "temperature": 0,
            "num_predict": 160,  # up to 5 fields × ~32 tokens each
        },
    }

    model_started = now_ms()
    update_metric("model_calls", 1)
    response = session.post(OLLAMA_URL, data=json_dumps(request_body), timeout=MODEL_TIMEOUT_SECONDS)
    response.raise_for_status()
    model_elapsed = now_ms() - model_started
    update_running_average("avg_model_ms", model_elapsed, "model_calls")

    data = response.json()
    raw_text = data.get("response", "")
    last_model_error = None
    last_model_success_at = time.time()
    logger.info(
        "ollama_ms=%.1f load_ns=%s eval_count=%s total_ns=%s",
        model_elapsed,
        data.get("load_duration"),
        data.get("eval_count"),
        data.get("total_duration"),
    )
    return parse_ollama_response(raw_text, fields)


def compute_insights(payload: dict[str, Any], fields: list[str]) -> dict[str, str]:
    global last_model_error
    try:
        generated = call_ollama(payload, fields)
    except requests.exceptions.Timeout:
        update_metric("model_failures", 1)
        last_model_error = f"timeout after {MODEL_TIMEOUT_SECONDS:.1f}s"
        logger.warning("ollama timeout after %.1fs", MODEL_TIMEOUT_SECONDS)
        return empty_insights(fields)
    except Exception as exc:
        update_metric("model_failures", 1)
        last_model_error = str(exc)
        logger.warning("ollama error: %s", exc)
        return empty_insights(fields)

    return normalize_generated_insights(generated, fields)


def get_or_compute(cache_key: str, payload: dict[str, Any], fields: list[str], force_refresh: bool) -> tuple[dict[str, str], bool]:
    if not force_refresh:
        cached = get_cached(cache_key)
        if cached is not None:
            update_metric("cache_hits", 1)
            return cached, True

    update_metric("cache_misses", 1)
    owner = False

    with inflight_lock:
        future = inflight.get(cache_key)
        if future is None:
            future = executor.submit(compute_insights, payload, fields)
            inflight[cache_key] = future
            owner = True
        else:
            update_metric("inflight_waits", 1)

    try:
        result = future.result(timeout=MODEL_TIMEOUT_SECONDS + 1.0)
    except TimeoutError:
        result = empty_insights(fields)
    finally:
        if owner:
            with inflight_lock:
                inflight.pop(cache_key, None)

    set_cached(cache_key, result)
    return result, False


def maybe_start_ngrok() -> None:
    global PUBLIC_BASE_URL

    if not AUTO_START_NGROK:
        return

    if ngrok is None:
        logger.warning("AUTO_START_NGROK=true but pyngrok is not installed")
        return

    try:
        if NGROK_AUTHTOKEN:
            ngrok.set_auth_token(NGROK_AUTHTOKEN)

        tunnel_kwargs: dict[str, Any] = {"addr": PORT, "proto": "http"}
        if NGROK_DOMAIN:
            tunnel_kwargs["domain"] = NGROK_DOMAIN

        tunnel = ngrok.connect(**tunnel_kwargs)
        PUBLIC_BASE_URL = tunnel.public_url.rstrip("/")
        logger.info("ngrok started at %s", PUBLIC_BASE_URL)
    except Exception as exc:
        logger.warning("ngrok auto-start failed: %s", exc)


def warm_model_once() -> None:
    warm_prompt = {
        "model": MODEL,
        "prompt": "Return exactly {}",
        "stream": False,
        "format": "json",
        "keep_alive": MODEL_KEEP_ALIVE,
        "options": {
            "temperature": 0,
            "num_predict": 4,
        },
    }

    try:
        started = now_ms()
        response = session.post(OLLAMA_URL, data=json_dumps(warm_prompt), timeout=max(MODEL_TIMEOUT_SECONDS, 20))
        response.raise_for_status()
        logger.info("ollama warmup completed in %.1fms", now_ms() - started)
    except Exception as exc:
        logger.warning("ollama warmup failed: %s", exc)


def maybe_start_model_warmup() -> None:
    if not WARM_MODEL_ON_START:
        return
    executor.submit(warm_model_once)


def demo_nudge_payloads() -> dict[str, Any]:
    """
    One representative payload per trigger.
    Includes all optional context fields so the debug page shows full prompts.
    """
    profile = {
        "monthly_income":       52000,
        "career_stage":         "early",
        "spending_personality": "impulse",
        "city":                 "Delhi",
    }
    return {
        # ── Category Breakdown / Home screen ─────────────────────────────────
        "overspend": {
            "trigger": "overspend",
            "user_profile": profile,
            "context": {
                "category":           "Food & Dining",
                "spent":              6800,
                "budget":             5000,
                "goal_name":          "Goa Trip",
                "days_left_in_month": 15,
            },
        },
        # ── Category Breakdown / Goals screen ────────────────────────────────
        "post_purchase": {
            "trigger": "post_purchase",
            "user_profile": profile,
            "context": {
                "last_purchase_amount":   1800,
                "last_purchase_category": "Dining Out",
                "goal_name":              "Goa Trip",
                "goal_saved":             28000,
                "goal_target":            35000,
                "monthly_contribution":   3500,
            },
        },
        # ── Goals screen ──────────────────────────────────────────────────────
        "goal_update": {
            "trigger": "goal_update",
            "user_profile": profile,
            "context": {
                "goal_name":            "Emergency Fund",
                "goal_target":          150000,
                "goal_saved":           112500,
                "monthly_contribution": 7500,
            },
        },
        # ── Subs & Bills screen ───────────────────────────────────────────────
        "subscription_audit": {
            "trigger": "subscription_audit",
            "user_profile": profile,
            "context": {
                "subscription_name":       "Hotstar",
                "subscription_monthly":    299,
                "months_since_last_used":  3,
                "opportunity_label":       "a day trip to Jaipur",
            },
        },
        # ── Home screen ───────────────────────────────────────────────────────
        "habit_builder": {
            "trigger": "habit_builder",
            "user_profile": profile,
            "context": {
                "week_number":    3,
                "week_savings":   1200,
                "challenge_name": "No-Spend Weekday",
                "streak_weeks":   3,
            },
        },
    }


def demo_payload() -> dict[str, Any]:
    return {
        # ── Month Summary screen ──────────────────────────────────────────────
        "summary": {
            "month_name":              "May",
            "year":                    2026,
            "days_elapsed":            16,
            "days_in_month":           31,
            "total_expense":           18420,
            "total_income":            52000,
            "daily_average":           1151.25,
            "previous_month_average":  980.00,
            "transaction_count":       34,
            "highest_spend_day":       11,
            "highest_spend_day_amount": 4200,
            "budget":                  34000,
            "remaining_budget":        15580,
        },
        # ── Category Breakdown screen ─────────────────────────────────────────
        "category": {
            "total_expense": 18420,
            "category_count": 6,
            "top_categories": [
                {"name": "Food & Dining",  "amount": 6800,  "share_percent": 37, "budget": 5000},
                {"name": "Transport",      "amount": 3940,  "share_percent": 21, "budget": 4000},
                {"name": "Shopping",       "amount": 3100,  "share_percent": 17, "budget": 3000},
                {"name": "Entertainment",  "amount": 2100,  "share_percent": 11, "budget": 2000},
                {"name": "Utilities",      "amount": 1480,  "share_percent":  8, "budget": 2000},
                {"name": "Health",         "amount": 1000,  "share_percent":  5, "budget": 1500},
            ],
        },
        # ── Subs & Bills screen ───────────────────────────────────────────────
        "subs_and_bills": {
            "month_name":                 "May",
            "unpaid_bills_count":         3,
            "upcoming_bills_total":       4280,
            "next_bill_name":             "Electricity Bill",
            "next_bill_amount":           1640,
            "next_bill_due_date":         "2026-05-19",
            "days_until_next_bill":       3,
            "active_subscription_count":  5,
            "monthly_subscription_total": 2847,
            "subscriptions": [
                {"name": "Netflix",        "monthly": 649,  "months_since_last_used": 0},
                {"name": "Spotify",        "monthly": 119,  "months_since_last_used": 0},
                {"name": "Amazon Prime",   "monthly": 299,  "months_since_last_used": 0},
                {"name": "Hotstar",        "monthly": 299,  "months_since_last_used": 3},
                {"name": "LinkedIn Premium","monthly": 1481, "months_since_last_used": 1},
            ],
        },
        # ── Goals screen ──────────────────────────────────────────────────────
        "goals": [
            {
                "name":                 "Emergency Fund",
                "target":               150000,
                "saved":                112500,
                "monthly_contribution": 7500,
                "deadline_months":      6,
            },
            {
                "name":                 "Goa Trip",
                "target":               35000,
                "saved":                28000,
                "monthly_contribution": 3500,
                "deadline_months":      2,
            },
            {
                "name":                 "New Laptop",
                "target":               80000,
                "saved":                12000,
                "monthly_contribution": 4000,
                "deadline_months":      18,
            },
        ],
        # ── Request shape ─────────────────────────────────────────────────────
        "fields":        list(ALLOWED_FIELDS),
        "force_refresh": False,
    }


def debug_page_html() -> str:
    sample_json = json.dumps(demo_payload(), indent=2)
    nudge_samples = json.dumps(demo_nudge_payloads(), indent=2)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Mint Insights Debug</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #f5f6f2;
      --card: #ffffff;
      --ink: #1f2a1f;
      --muted: #5f6d5f;
      --brand: #496749;
      --border: #d7ddd4;
      --accent: #7b4ea0;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      padding: 24px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: var(--bg);
      color: var(--ink);
    }}
    .wrap {{
      max-width: 900px;
      margin: 0 auto;
      display: grid;
      gap: 16px;
    }}
    .card {{
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 18px;
      padding: 16px;
    }}
    h1 {{ margin: 0 0 8px; font-size: 28px; }}
    h2 {{ margin: 0 0 12px; font-size: 20px; }}
    p {{ margin: 0; color: var(--muted); line-height: 1.5; }}
    textarea, pre {{
      width: 100%;
      border-radius: 14px;
      border: 1px solid var(--border);
      padding: 14px;
      background: #fbfcfa;
      color: var(--ink);
      font: 13px/1.45 ui-monospace, SFMono-Regular, Menlo, monospace;
      overflow: auto;
    }}
    textarea {{ min-height: 320px; resize: vertical; }}
    pre {{ min-height: 100px; white-space: pre-wrap; word-break: break-word; }}
    .row {{
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      align-items: center;
    }}
    button {{
      appearance: none;
      border: 0;
      border-radius: 999px;
      padding: 12px 18px;
      font-weight: 600;
      cursor: pointer;
      background: var(--brand);
      color: white;
    }}
    button.secondary {{ background: #e6ece3; color: var(--ink); }}
    button.nudge {{ background: var(--accent); }}
    .status {{ font-size: 14px; color: var(--muted); }}
    .tabs {{ display: flex; gap: 8px; margin-bottom: 4px; }}
    .tab {{
      padding: 8px 18px;
      border-radius: 999px;
      font-weight: 600;
      font-size: 14px;
      cursor: pointer;
      border: 2px solid var(--border);
      background: var(--card);
      color: var(--muted);
    }}
    .tab.active {{ border-color: var(--brand); color: var(--brand); }}
    .tab.active.nudge-tab {{ border-color: var(--accent); color: var(--accent); }}
    .panel {{ display: none; }}
    .panel.active {{ display: contents; }}
    select {{
      padding: 10px 14px;
      border-radius: 12px;
      border: 1px solid var(--border);
      background: var(--card);
      color: var(--ink);
      font-size: 14px;
      cursor: pointer;
    }}
    .nudge-result {{
      background: #f9f5ff;
      border: 1px solid #d4b8f0;
      border-radius: 14px;
      padding: 16px;
      font-size: 15px;
      line-height: 1.6;
    }}
    .nudge-principle {{ font-size: 12px; color: var(--accent); margin-top: 8px; font-weight: 600; }}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>Mint Insights Debug</h1>
      <p>Test the insights and behavioural nudge endpoints before wiring them into the app.</p>
    </div>

    <div class="card">
      <div class="tabs">
        <div class="tab active" id="tab-insights" onclick="switchTab('insights')">Insights</div>
        <div class="tab nudge-tab" id="tab-nudges" onclick="switchTab('nudges')">Nudges</div>
      </div>
    </div>

    <!-- ── Insights panel ── -->
    <div class="panel active" id="panel-insights">
      <div class="card">
        <div class="row">
          <button id="healthBtn" class="secondary">Check Health</button>
          <button id="runBtn">Run Sample Insight</button>
          <button id="customBtn" class="secondary">Run Custom Payload</button>
          <span id="insightsStatus" class="status">Ready.</span>
        </div>
      </div>
      <div class="card">
        <h2>Payload</h2>
        <textarea id="insightsPayload">{sample_json}</textarea>
      </div>
      <div class="card">
        <h2>Response</h2>
        <pre id="insightsResponse">No request yet.</pre>
      </div>
    </div>

    <!-- ── Nudges panel ── -->
    <div class="panel" id="panel-nudges">
      <div class="card">
        <div class="row">
          <select id="nudgeTrigger">
            <option value="overspend">overspend</option>
            <option value="post_purchase">post_purchase</option>
            <option value="goal_update">goal_update</option>
            <option value="subscription_audit">subscription_audit</option>
            <option value="habit_builder">habit_builder</option>
          </select>
          <button id="loadNudgeSample" class="secondary">Load Sample</button>
          <button id="runNudgeBtn" class="nudge">Generate Nudge</button>
          <span id="nudgesStatus" class="status">Ready.</span>
        </div>
      </div>
      <div class="card">
        <h2>Payload</h2>
        <textarea id="nudgesPayload" style="min-height:260px;"></textarea>
      </div>
      <div class="card">
        <h2>Nudge</h2>
        <div id="nudgeDisplay" class="nudge-result" style="display:none;"></div>
        <pre id="nudgesResponse">No request yet.</pre>
      </div>
    </div>
  </div>

  <script>
    const NUDGE_SAMPLES = {nudge_samples};

    function switchTab(name) {{
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
      document.getElementById('tab-' + name).classList.add('active');
      document.getElementById('panel-' + name).classList.add('active');
    }}

    async function runRequest(url, options, statusId, responseId) {{
      const started = performance.now();
      document.getElementById(statusId).textContent = 'Running...';
      document.getElementById(responseId).textContent = '';
      try {{
        const response = await fetch(url, options);
        const text = await response.text();
        const elapsed = Math.round(performance.now() - started);
        document.getElementById(statusId).textContent = `${{response.status}} in ${{elapsed}}ms`;
        try {{
          const json = JSON.parse(text);
          document.getElementById(responseId).textContent = JSON.stringify(json, null, 2);
          return json;
        }} catch {{
          document.getElementById(responseId).textContent = text;
        }}
      }} catch (error) {{
        document.getElementById(statusId).textContent = 'Request failed';
        document.getElementById(responseId).textContent = String(error);
      }}
      return null;
    }}

    // Insights tab
    document.getElementById('healthBtn').addEventListener('click', () => {{
      runRequest('/health', {{ method: 'GET' }}, 'insightsStatus', 'insightsResponse');
    }});

    document.getElementById('runBtn').addEventListener('click', () => {{
      document.getElementById('insightsPayload').value = {json.dumps(sample_json)};
      runRequest('/insights', {{
        method: 'POST',
        headers: {{ 'Content-Type': 'application/json' }},
        body: document.getElementById('insightsPayload').value,
      }}, 'insightsStatus', 'insightsResponse');
    }});

    document.getElementById('customBtn').addEventListener('click', () => {{
      runRequest('/insights', {{
        method: 'POST',
        headers: {{ 'Content-Type': 'application/json' }},
        body: document.getElementById('insightsPayload').value,
      }}, 'insightsStatus', 'insightsResponse');
    }});

    // Nudges tab — load sample on trigger change
    function loadNudgeSample() {{
      const trigger = document.getElementById('nudgeTrigger').value;
      const sample = NUDGE_SAMPLES[trigger];
      if (sample) {{
        document.getElementById('nudgesPayload').value = JSON.stringify(sample, null, 2);
      }}
    }}

    document.getElementById('loadNudgeSample').addEventListener('click', loadNudgeSample);
    document.getElementById('nudgeTrigger').addEventListener('change', loadNudgeSample);
    loadNudgeSample(); // populate on load

    document.getElementById('runNudgeBtn').addEventListener('click', async () => {{
      const display = document.getElementById('nudgeDisplay');
      display.style.display = 'none';
      const result = await runRequest('/nudges', {{
        method: 'POST',
        headers: {{ 'Content-Type': 'application/json' }},
        body: document.getElementById('nudgesPayload').value,
      }}, 'nudgesStatus', 'nudgesResponse');

      if (result && result.nudge) {{
        display.innerHTML = `<div>${{result.nudge}}</div><div class="nudge-principle">✦ ${{result.principle}}</div>`;
        display.style.display = 'block';
      }}
    }});
  </script>
</body>
</html>"""


@app.before_request
def before_request() -> None:
    g.request_started_ms = now_ms()
    update_metric("requests_total", 1)


@app.after_request
def after_request(response: Response) -> Response:
    elapsed_ms = now_ms() - getattr(g, "request_started_ms", now_ms())
    update_running_average("avg_request_ms", elapsed_ms, "requests_total")

    cache_state = response.headers.get("X-Cache", "-")
    logger.info("%s %s status=%s request_ms=%.1f cache=%s", request.method, request.path, response.status_code, elapsed_ms, cache_state)

    accepts_gzip = "gzip" in request.headers.get("Accept-Encoding", "").lower()
    if (
        accepts_gzip
        and response.status_code == 200
        and response.direct_passthrough is False
        and not response.headers.get("Content-Encoding")
        and response.mimetype == "application/json"
    ):
        payload = response.get_data()
        if len(payload) >= GZIP_MIN_BYTES:
            compressed = gzip.compress(payload, compresslevel=5)
            response.set_data(compressed)
            response.headers["Content-Encoding"] = "gzip"
            response.headers["Content-Length"] = str(len(compressed))
            response.headers["Vary"] = "Accept-Encoding"

    response.headers["X-Request-Time-Ms"] = f"{elapsed_ms:.1f}"
    return response


@app.route("/", methods=["GET"])
def debug_home() -> Response:
    return html_response(debug_page_html())


@app.route("/insights", methods=["POST"])
def insights() -> Response:
    body = request.get_json(silent=True) or {}
    payload, fields, force_refresh = normalize_payload(body)

    if not has_meaningful_data(payload, fields):
        response = json_response(filter_response_fields({field: "" for field in ALLOWED_FIELDS}, fields))
        response.headers["X-Cache"] = "skip"
        return response

    cache_key = payload_hash(payload, fields)
    result, was_cached = get_or_compute(cache_key, payload, fields, force_refresh)

    response_payload = filter_response_fields(result, fields)
    response = json_response(response_payload)
    response.headers["X-Cache"] = "hit" if was_cached else "miss"
    response.headers["X-Fields"] = ",".join(fields)
    return response


@app.route("/health", methods=["GET"])
def health() -> Response:
    health_payload = {
        "status": "ok",
        "model": MODEL,
        "ollama_url": OLLAMA_URL,
        "cache_ttl_seconds": CACHE_TTL_SECONDS,
        "cache_size": len(cache),
        "inflight_requests": len(inflight),
        "public_base_url": PUBLIC_BASE_URL or None,
        "warm_model_on_start": WARM_MODEL_ON_START,
        "last_model_error": last_model_error,
        "last_model_success_at": last_model_success_at,
        "metrics": metrics,
    }
    return json_response(health_payload)


@app.route("/nudges", methods=["POST"])
def nudges() -> Response:
    """
    Event-driven behavioural nudge endpoint.

    Expected body:
    {
        "trigger": "overspend" | "post_purchase" | "goal_update"
                   | "subscription_audit" | "habit_builder",
        "user_profile": {
            "monthly_income": 50000,
            "career_stage": "early",          // early | mid | senior
            "spending_personality": "impulse" // impulse | steady | saver
        },
        "context": {
            // overspend:           category, spent, budget, goal_name
            // post_purchase:       last_purchase_amount, last_purchase_category, goal_name
            // goal_update:         goal_name, goal_target, goal_saved
            // subscription_audit:  subscription_name, subscription_monthly
            // habit_builder:       week_number, week_savings, challenge_name
        }
    }

    Returns:
    {
        "nudge":     "<one sentence>",
        "principle": "<behavioural label>",
        "trigger":   "<trigger name>"
    }
    """
    body = request.get_json(silent=True) or {}
    trigger = str(body.get("trigger", "")).lower().strip()

    if trigger not in VALID_TRIGGERS:
        return json_response(
            {"error": f"trigger must be one of: {sorted(VALID_TRIGGERS)}"},
            status=400,
        )

    profile = body.get("user_profile") if isinstance(body.get("user_profile"), dict) else {}
    ctx = body.get("context") if isinstance(body.get("context"), dict) else {}

    # Nudges are event-driven — skip the shared insights cache.
    # Each trigger fires on a real user action so we want a fresh generation.
    result = compute_nudge(trigger, profile, ctx)
    response = json_response(result)
    response.headers["X-Nudge-Trigger"] = trigger
    return response


maybe_start_model_warmup()

if __name__ == "__main__":
    maybe_start_ngrok()
    app.run(host=HOST, port=PORT, debug=False, threaded=True)