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
ALLOWED_FIELDS = ("summary", "category_highlight", "subs_and_bills")
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
        "summary": raw_payload.get("summary") or {},
        "category": raw_payload.get("category") or {},
        "subs_and_bills": raw_payload.get("subs_and_bills") or raw_payload.get("subsAndBills") or {},
    }
    fields = normalize_fields(body.get("fields"))
    force_refresh = bool(body.get("force_refresh", False))
    return payload, fields, force_refresh


def filter_response_fields(payload: dict[str, str], fields: list[str]) -> dict[str, str]:
    return {field: payload.get(field, "") for field in fields}


def has_meaningful_data(payload: dict[str, Any], fields: list[str]) -> bool:
    summary = payload.get("summary", {})
    category = payload.get("category", {})
    subs_and_bills = payload.get("subs_and_bills", {})

    checks = {
        "summary": float(summary.get("total_expense") or 0) > 0 or float(summary.get("total_income") or 0) > 0,
        "category_highlight": float(category.get("total_expense") or 0) > 0 and bool(category.get("top_categories")),
        "subs_and_bills": int(subs_and_bills.get("unpaid_bills_count") or 0) > 0
        or int(subs_and_bills.get("active_subscription_count") or 0) > 0,
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
    lowered = text.lower()
    obvious_markers = (
        "spend is ",
        "spending is ",
        "spending stands at ",
        "peaked on day ",
        "leads spending at ",
        "upcoming unpaid bills currently add up to ",
        "active subscriptions total ",
    )

    if any(marker in lowered for marker in obvious_markers):
        return True

    due_markers = (" is due today.", " is due tomorrow.", " is due in ")
    if any(marker in lowered for marker in due_markers) and "set aside" not in lowered and "plan" not in lowered:
        return True

    return False


def normalize_generated_insights(generated: dict[str, str], fields: list[str]) -> dict[str, str]:
    normalized: dict[str, str] = {}
    for field in fields:
        text = clean_sentence(generated.get(field))
        normalized[field] = "" if is_low_value_insight(text) else text
    return normalized


def build_prompt(payload: dict[str, Any], fields: list[str]) -> str:
    requested_shape = {field: "" for field in fields}
    compact_payload = {
        "summary": payload.get("summary", {}),
        "category": payload.get("category", {}),
        "subs_and_bills": payload.get("subs_and_bills", {}),
    }
    return (
        "You write optional financial coaching insights for a mobile app.\n"
        "Return only valid JSON.\n"
        "Each key must map to exactly one sentence or an empty string.\n"
        "Every non-empty value must be one sentence, under 18 words.\n"
        "Use only the provided numbers.\n"
        "Use the ₹ symbol for money.\n"
        "Do not restate what is already obvious from the charts or cards.\n"
        "Only return text when it adds non-obvious context, a risk, a comparison, or a habit-building nudge.\n"
        "If a section lacks useful coaching value, return an empty string.\n"
        "Avoid generic observations like due dates, totals, or category leaders unless you add guidance.\n\n"
        f"Return this exact JSON shape:\n{canonical_json(requested_shape)}\n\n"
        f"Metrics:\n{canonical_json(compact_payload)}"
    )


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
            "num_predict": 96,
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


def demo_payload() -> dict[str, Any]:
    return {
        "summary": {
            "month_name": "April",
            "year": 2026,
            "days_elapsed": 8,
            "days_in_month": 30,
            "total_expense": 3390,
            "total_income": 28500,
            "daily_average": 423.75,
            "previous_month_average": 57.42,
            "transaction_count": 12,
            "highest_spend_day": 6,
            "highest_spend_day_amount": 840,
            "budget": 24000,
            "remaining_budget": 20610,
        },
        "category": {
            "total_expense": 3390,
            "category_count": 4,
            "top_categories": [
                {"name": "Food", "amount": 1180, "share_percent": 35},
                {"name": "Transport", "amount": 760, "share_percent": 22},
            ],
        },
        "subs_and_bills": {
            "month_name": "April",
            "unpaid_bills_count": 2,
            "upcoming_bills_total": 828,
            "next_bill_name": "Electricity Bill",
            "next_bill_amount": 540,
            "next_bill_due_date": "2026-04-11",
            "days_until_next_bill": 3,
            "active_subscription_count": 4,
            "monthly_subscription_total": 3672,
        },
        "fields": list(ALLOWED_FIELDS),
        "force_refresh": False,
    }


def debug_page_html() -> str:
    sample_json = json.dumps(demo_payload(), indent=2)
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
    pre {{ min-height: 200px; white-space: pre-wrap; word-break: break-word; }}
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
      background: var(--brand);
      color: white;
    }}
    button.secondary {{
      background: #e6ece3;
      color: var(--ink);
    }}
    .status {{
      font-size: 14px;
      color: var(--muted);
    }}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>Mint Insights Debug</h1>
      <p>Use this page to test the backend directly through ngrok before wiring it into the app.</p>
    </div>

    <div class="card">
      <div class="row">
        <button id="healthBtn" class="secondary">Check Health</button>
        <button id="runBtn">Run Sample Insight</button>
        <button id="customBtn" class="secondary">Run Custom Payload</button>
        <span id="status" class="status">Ready.</span>
      </div>
    </div>

    <div class="card">
      <h1 style="font-size:20px; margin-bottom:12px;">Payload</h1>
      <textarea id="payload">{sample_json}</textarea>
    </div>

    <div class="card">
      <h1 style="font-size:20px; margin-bottom:12px;">Response</h1>
      <pre id="response">No request yet.</pre>
    </div>
  </div>

  <script>
    const payloadBox = document.getElementById('payload');
    const responseBox = document.getElementById('response');
    const statusBox = document.getElementById('status');

    async function runRequest(url, options) {{
      const started = performance.now();
      statusBox.textContent = 'Running...';
      responseBox.textContent = '';
      try {{
        const response = await fetch(url, options);
        const text = await response.text();
        const elapsed = Math.round(performance.now() - started);
        statusBox.textContent = `${{response.status}} in ${{elapsed}}ms`;
        try {{
          const json = JSON.parse(text);
          responseBox.textContent = JSON.stringify(json, null, 2);
        }} catch {{
          responseBox.textContent = text;
        }}
      }} catch (error) {{
        statusBox.textContent = 'Request failed';
        responseBox.textContent = String(error);
      }}
    }}

    document.getElementById('healthBtn').addEventListener('click', () => {{
      runRequest('/health', {{ method: 'GET' }});
    }});

    document.getElementById('runBtn').addEventListener('click', () => {{
      payloadBox.value = {json.dumps(sample_json)};
      runRequest('/insights', {{
        method: 'POST',
        headers: {{ 'Content-Type': 'application/json' }},
        body: payloadBox.value,
      }});
    }});

    document.getElementById('customBtn').addEventListener('click', () => {{
      runRequest('/insights', {{
        method: 'POST',
        headers: {{ 'Content-Type': 'application/json' }},
        body: payloadBox.value,
      }});
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


maybe_start_model_warmup()

if __name__ == "__main__":
    maybe_start_ngrok()
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
