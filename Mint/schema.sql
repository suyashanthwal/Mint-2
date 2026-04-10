-- =============================================================
--  PRAGMAS
-- =============================================================
PRAGMA foreign_keys = ON;
PRAGMA journal_mode  = WAL;

-- =============================================================
--  TABLE: users
-- =============================================================
CREATE TABLE IF NOT EXISTS users (
    id                      TEXT    PRIMARY KEY,
    name                    TEXT    NOT NULL,
    phone_number            TEXT    NOT NULL,
    email                   TEXT    NOT NULL UNIQUE,
    currency                TEXT    NOT NULL DEFAULT 'INR',
    is_email_auto_forward   INTEGER NOT NULL DEFAULT 0,
    is_pin_enabled          INTEGER NOT NULL DEFAULT 0,
    is_biometric_enabled    INTEGER NOT NULL DEFAULT 0,
    is_dark_mode_enabled    INTEGER NOT NULL DEFAULT 0,
    is_notification_enabled INTEGER NOT NULL DEFAULT 1,
    profile_image_name      TEXT,
    created_on              TEXT    NOT NULL
);

-- =============================================================
--  TABLE: onboarding_states
--
--  Persists whether a user has already seen a given screen's
--  onboarding walkthrough. This survives sign out and app relaunches,
--  and for seeded accounts it can be recreated on reinstall.
-- =============================================================
CREATE TABLE IF NOT EXISTS onboarding_states (
    user_id         TEXT    NOT NULL,
    onboarding_key  TEXT    NOT NULL,
    is_seen         INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT    NOT NULL,
    updated_at      TEXT    NOT NULL,
    PRIMARY KEY (user_id, onboarding_key),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_onboarding_states_user ON onboarding_states(user_id);

-- =============================================================
--  TABLE: categories
--
--  `budget` = planned monthly allocation for that category.
--  Category budgets can represent just the discretionary slice
--  of the user's monthly budget, so they do not have to equal
--  `allocated_budget` on their own.
--
--  EXCLUDED: remaining, isOver, percentageUsed
--  Computed at query time via SUM(transactions.amount).
-- =============================================================
CREATE TABLE IF NOT EXISTS categories (
    id          TEXT    PRIMARY KEY,
    user_id     TEXT    NOT NULL,
    name        TEXT    NOT NULL,
    color       TEXT    NOT NULL,
    icon        TEXT    NOT NULL,
    budget      REAL    NOT NULL DEFAULT 0,
    type        TEXT    NOT NULL DEFAULT 'expense'
                        CHECK(type IN ('expense','income')),
    created_at  TEXT    NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_categories_user ON categories(user_id);

-- =============================================================
--  TABLE: transactions
-- =============================================================
CREATE TABLE IF NOT EXISTS transactions (
    id                  TEXT    PRIMARY KEY,
    user_id             TEXT    NOT NULL,
    name                TEXT    NOT NULL,
    amount              REAL    NOT NULL,
    timestamp           TEXT    NOT NULL,
    note                TEXT,
    created_at          TEXT    NOT NULL,
    source              TEXT    NOT NULL
                                CHECK(source IN ('upi','manual','receipt','ecommerce')),
    type                TEXT    NOT NULL
                                CHECK(type IN ('income','expense')),
    source_name         TEXT,
    category_id         TEXT,
    status              INTEGER,
    expense_type        TEXT,
    upi_transaction_id  TEXT,
    upi_merchant_name   TEXT,
    upi_currency_type   TEXT,
    FOREIGN KEY (user_id)     REFERENCES users(id)      ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_txn_user      ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_txn_timestamp ON transactions(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_txn_category  ON transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_txn_type      ON transactions(type);

-- =============================================================
--  TABLE: buffer_transactions
--
--  Holds transactions that still need the user's confirmation
--  before being copied into the main transactions table.
-- =============================================================
CREATE TABLE IF NOT EXISTS buffer_transactions (
    id                  TEXT    PRIMARY KEY,
    user_id             TEXT    NOT NULL,
    name                TEXT    NOT NULL,
    amount              REAL    NOT NULL,
    timestamp           TEXT    NOT NULL,
    note                TEXT,
    created_at          TEXT    NOT NULL,
    source              TEXT    NOT NULL
                                CHECK(source IN ('upi','manual','receipt','ecommerce')),
    type                TEXT    NOT NULL
                                CHECK(type IN ('income','expense')),
    source_name         TEXT,
    category_id         TEXT,
    status              INTEGER,
    expense_type        TEXT,
    upi_transaction_id  TEXT,
    upi_merchant_name   TEXT,
    upi_currency_type   TEXT,
    FOREIGN KEY (user_id)     REFERENCES users(id)      ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_buffer_txn_user       ON buffer_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_buffer_txn_created_at ON buffer_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_buffer_txn_type       ON buffer_transactions(type);

-- =============================================================
--  TABLE: bills
-- =============================================================
CREATE TABLE IF NOT EXISTS bills (
    id               TEXT    PRIMARY KEY,
    user_id          TEXT    NOT NULL,
    icon             TEXT    NOT NULL,
    name             TEXT    NOT NULL,
    category_id      TEXT    NOT NULL,
    amount           REAL    NOT NULL,
    bill_date        TEXT    NOT NULL,
    range            TEXT    NOT NULL
                             CHECK(range IN ('daily','weekly','monthly','yearly')),
    is_paid          INTEGER NOT NULL DEFAULT 0,
    is_alert_enabled INTEGER NOT NULL DEFAULT 1,
    note             TEXT,
    created_at       TEXT    NOT NULL,
    FOREIGN KEY (user_id)     REFERENCES users(id)      ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_bills_user ON bills(user_id);
CREATE INDEX IF NOT EXISTS idx_bills_date ON bills(bill_date);
CREATE INDEX IF NOT EXISTS idx_bills_paid ON bills(is_paid);

-- =============================================================
--  TABLE: budgets
--
--  SINGLE-ROW DESIGN: one budget per user, always active.
--  There is no start_date/end_date — the budget is a standing
--  monthly configuration, not a date-ranged record.
--
--  `allocated_budget`  — the user's total monthly budget.
--                        It can cover category allocations,
--                        fixed expenses, and goal contributions.
--  `total_expense`     — running month-to-date spend. Maintained
--                        by the app; zeroed each month via
--                        DatabaseManager.resetMonthlyExpense().
--  `daily_limit`       — derived suggestion (allocated_budget / days
--                        in month), stored for offline display.
--  `last_reset_date`   — ISO 8601 date of last monthly reset so
--                        the app can detect a new month on launch.
--
--  EXCLUDED: remainingBudget (= allocated_budget - total_expense).
-- =============================================================
CREATE TABLE IF NOT EXISTS budgets (
    id               TEXT    PRIMARY KEY,
    user_id          TEXT    NOT NULL UNIQUE,   -- one budget per user
    allocated_budget REAL    NOT NULL,
    total_expense    REAL    NOT NULL DEFAULT 0,
    daily_limit      REAL    NOT NULL,
    last_reset_date  TEXT    NOT NULL,          -- ISO 8601, e.g. "2026-04-01"
    created_at       TEXT    NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =============================================================
--  TABLE: budget_categories  (many-to-many join)
--  Maps which expense categories contribute to the budget.
-- =============================================================
CREATE TABLE IF NOT EXISTS budget_categories (
    budget_id   TEXT NOT NULL,
    category_id TEXT NOT NULL,
    PRIMARY KEY (budget_id, category_id),
    FOREIGN KEY (budget_id)   REFERENCES budgets(id)    ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);

-- =============================================================
--  TABLE: goals
-- =============================================================
CREATE TABLE IF NOT EXISTS goals (
    id              TEXT    PRIMARY KEY,
    user_id         TEXT    NOT NULL,
    name            TEXT    NOT NULL,
    target_amount   REAL    NOT NULL,
    currently_saved REAL    NOT NULL DEFAULT 0,
    target_date     TEXT    NOT NULL,
    monthly_goal    REAL    NOT NULL,
    icon_name       TEXT    NOT NULL,
    image_name      TEXT,
    is_completed    INTEGER NOT NULL DEFAULT 0,
    completed_on    TEXT,
    created_at      TEXT    NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =============================================================
--  TABLE: recurring_payments
-- =============================================================
CREATE TABLE IF NOT EXISTS recurring_payments (
    id                   TEXT    PRIMARY KEY,
    user_id              TEXT    NOT NULL,
    name                 TEXT    NOT NULL,
    category_id          TEXT,
    duration             TEXT    NOT NULL
                                 CHECK(duration IN ('daily','weekly','monthly','yearly')),
    amount               REAL    NOT NULL,
    last_date            TEXT,
    next_date            TEXT    NOT NULL,
    is_active            INTEGER NOT NULL DEFAULT 1,
    is_alert_enabled     INTEGER NOT NULL DEFAULT 1,
    is_add_automatically INTEGER NOT NULL DEFAULT 1,
    repeat_count         INTEGER NOT NULL DEFAULT 0,
    total_amount         REAL    NOT NULL DEFAULT 0,
    icon                 TEXT,
    note                 TEXT,
    is_income            INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (user_id)     REFERENCES users(id)      ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- =============================================================
--  TABLE: receipts
-- =============================================================
CREATE TABLE IF NOT EXISTS receipts (
    id            TEXT    PRIMARY KEY,
    user_id       TEXT    NOT NULL,
    merchant_name TEXT    NOT NULL,
    total_amount  REAL    NOT NULL,
    date          TEXT    NOT NULL,
    note          TEXT,
    created_at    TEXT    NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =============================================================
--  TABLE: receipt_transactions  (many-to-many join)
-- =============================================================
CREATE TABLE IF NOT EXISTS receipt_transactions (
    receipt_id     TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    PRIMARY KEY (receipt_id, transaction_id),
    FOREIGN KEY (receipt_id)     REFERENCES receipts(id)     ON DELETE CASCADE,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
);
