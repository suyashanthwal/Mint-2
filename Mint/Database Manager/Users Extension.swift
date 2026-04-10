import Foundation
import SQLite3

extension DatabaseManager {

    struct UserRecord {
        let id: UUID
        let name: String
        let email: String
    }

    private static let passwordStoreKey = "stored_account_passwords"
    private static let defaultAdminPassword = "admin123"
    private static let defaultAdminOnboardingKeys = [
        OnboardingKeys.home,
        OnboardingKeys.budget,
        OnboardingKeys.reports,
        OnboardingKeys.goals,
        OnboardingKeys.payPlus
    ]

    func ensureDefaultAdminAccountState() {
        execute(
            "UPDATE users SET name = ? WHERE id = ?;",
            args: ["Mint Admin", Self.defaultAdminUserId.uuidString]
        )

        guard let admin = fetchUser(id: Self.defaultAdminUserId) else { return }
        storePasswordIfMissing(Self.defaultAdminPassword, for: admin.email)
        markSetupComplete(for: admin.id, isComplete: true)
    }

    func ensureDefaultAdminSeedDataIsCurrent() {
        let storedSeedVersion = storedDefaultAdminSeedVersion()
        guard storedSeedVersion < Self.currentDefaultAdminSeedVersion else { return }

        if storedSeedVersion >= 2 {
            ensureDefaultAdminBufferedSampleData()
            ensureDefaultAdminOnboardingStates()
            ensureDefaultAdminAccountState()
            markDefaultAdminSeedVersionCurrent()
            return
        }

        let wasCurrentAdmin = currentUserId == Self.defaultAdminUserId

        execute("DELETE FROM users WHERE id = ?;", args: [Self.defaultAdminUserId.uuidString])
        runSQLFile(named: "seed")
        ensureDefaultAdminAccountState()

        if wasCurrentAdmin {
            setCurrentUser(id: Self.defaultAdminUserId)
        }

        markDefaultAdminSeedVersionCurrent()
    }

    private func ensureDefaultAdminBufferedSampleData() {
        guard fetchUser(id: Self.defaultAdminUserId) != nil else { return }
        guard defaultAdminBufferedTransactionCount() == 0 else { return }

        executeStatements(
            """
            INSERT OR IGNORE INTO buffer_transactions
                (id, user_id, name, amount, timestamp, note, created_at,
                 source, type, source_name, category_id, status, expense_type,
                 upi_transaction_id, upi_merchant_name, upi_currency_type)
            VALUES
            ('21000000-0000-0000-0000-000000000001',
             '00000000-0000-0000-0000-000000000001',
             'Bakery Receipt', 210, '2026-04-07T11:45:00', 'Receipt scan pending confirmation', '2026-04-07T11:50:00',
             'receipt', 'expense', NULL,
             '10000000-0000-0000-0000-000000000001', 1, 'meal',
             NULL, NULL, NULL),

            ('21000000-0000-0000-0000-000000000002',
             '00000000-0000-0000-0000-000000000001',
             'Roommate Settlement', 850, '2026-04-07T12:05:00', 'Incoming payment pending confirmation', '2026-04-07T12:08:00',
             'manual', 'income', 'Roommate',
             NULL, NULL, NULL,
             NULL, NULL, NULL);
            """
        )
    }

    private func ensureDefaultAdminOnboardingStates() {
        guard fetchUser(id: Self.defaultAdminUserId) != nil else { return }

        let timestamp = databaseTimestampString(from: Date())
        let values = Self.defaultAdminOnboardingKeys
            .map {
                "('\(Self.defaultAdminUserId.uuidString)', '\($0)', 1, '\(timestamp)', '\(timestamp)')"
            }
            .joined(separator: ",\n")

        executeStatements(
            """
            INSERT OR IGNORE INTO onboarding_states
                (user_id, onboarding_key, is_seen, created_at, updated_at)
            VALUES
            \(values);
            """
        )
    }

    private func defaultAdminBufferedTransactionCount() -> Int {
        let query = "SELECT COUNT(*) FROM buffer_transactions WHERE user_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (Self.defaultAdminUserId.uuidString as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    func hasSeenOnboarding(key: String, for userId: UUID) -> Bool {
        let query = """
        SELECT is_seen
        FROM onboarding_states
        WHERE user_id = ? AND onboarding_key = ?
        LIMIT 1;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (userId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (key as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return false }
        return sqlite3_column_int(stmt, 0) == 1
    }

    func markOnboardingSeen(key: String, for userId: UUID) {
        let query = """
        INSERT INTO onboarding_states
            (user_id, onboarding_key, is_seen, created_at, updated_at)
        VALUES (?, ?, 1, ?, ?)
        ON CONFLICT(user_id, onboarding_key)
        DO UPDATE SET is_seen = 1, updated_at = excluded.updated_at;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ markOnboardingSeen: prepare failed")
            return
        }
        defer { sqlite3_finalize(stmt) }

        let timestamp = databaseTimestampString(from: Date())
        sqlite3_bind_text(stmt, 1, (userId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (key as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (timestamp as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (timestamp as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            print("❌ markOnboardingSeen failed: \(String(cString: sqlite3_errmsg(db)))")
            return
        }
    }

    func fetchUser(id: UUID) -> UserRecord? {
        let query = "SELECT id, name, email FROM users WHERE id = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (id.uuidString as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW,
              let idPtr = sqlite3_column_text(stmt, 0),
              let userId = UUID(uuidString: String(cString: idPtr)),
              let namePtr = sqlite3_column_text(stmt, 1),
              let emailPtr = sqlite3_column_text(stmt, 2)
        else { return nil }

        return UserRecord(
            id: userId,
            name: String(cString: namePtr),
            email: String(cString: emailPtr)
        )
    }

    func fetchUser(email: String) -> UserRecord? {
        let normalizedEmail = normalizeEmail(email)
        let query = "SELECT id, name, email FROM users WHERE lower(email) = lower(?) LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (normalizedEmail as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW,
              let idPtr = sqlite3_column_text(stmt, 0),
              let userId = UUID(uuidString: String(cString: idPtr)),
              let namePtr = sqlite3_column_text(stmt, 1),
              let emailPtr = sqlite3_column_text(stmt, 2)
        else { return nil }

        return UserRecord(
            id: userId,
            name: String(cString: namePtr),
            email: String(cString: emailPtr)
        )
    }

    func fetchCurrentUser() -> UserRecord? {
        guard let currentUserId else { return nil }
        return fetchUser(id: currentUserId)
    }

    @discardableResult
    func createUserAccount(email: String, password: String) -> UUID? {
        let normalizedEmail = normalizeEmail(email)
        guard !normalizedEmail.isEmpty, !password.isEmpty else { return nil }
        guard fetchUser(email: normalizedEmail) == nil else { return nil }

        let userId = UUID()
        let budgetId = UUID()
        let iso = ISO8601DateFormatter()
        let createdAt = iso.string(from: Date())

        let resetFormatter = DateFormatter()
        resetFormatter.dateFormat = "yyyy-MM-dd"
        let lastResetDate = resetFormatter.string(from: Date())

        let userSQL = """
        INSERT INTO users
            (id, name, phone_number, email, currency,
             is_email_auto_forward, is_pin_enabled, is_biometric_enabled,
             is_dark_mode_enabled, is_notification_enabled, profile_image_name, created_on)
        VALUES (?, ?, ?, ?, 'INR', 0, 0, 0, 0, 1, NULL, ?);
        """

        var userStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, userSQL, -1, &userStmt, nil) == SQLITE_OK else {
            print("❌ createUserAccount: user prepare failed")
            return nil
        }

        let displayName = makeDisplayName(from: normalizedEmail)
        sqlite3_bind_text(userStmt, 1, (userId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(userStmt, 2, (displayName as NSString).utf8String, -1, nil)
        sqlite3_bind_text(userStmt, 3, ("0000000000" as NSString).utf8String, -1, nil)
        sqlite3_bind_text(userStmt, 4, (normalizedEmail as NSString).utf8String, -1, nil)
        sqlite3_bind_text(userStmt, 5, (createdAt as NSString).utf8String, -1, nil)

        guard sqlite3_step(userStmt) == SQLITE_DONE else {
            print("❌ createUserAccount: user insert failed: \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_finalize(userStmt)
            return nil
        }
        sqlite3_finalize(userStmt)

        let budgetSQL = """
        INSERT INTO budgets
            (id, user_id, allocated_budget, total_expense, daily_limit, last_reset_date, created_at)
        VALUES (?, ?, 0, 0, 0, ?, ?);
        """

        var budgetStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, budgetSQL, -1, &budgetStmt, nil) == SQLITE_OK else {
            print("❌ createUserAccount: budget prepare failed")
            execute("DELETE FROM users WHERE id = ?;", args: [userId.uuidString])
            return nil
        }

        sqlite3_bind_text(budgetStmt, 1, (budgetId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(budgetStmt, 2, (userId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(budgetStmt, 3, (lastResetDate as NSString).utf8String, -1, nil)
        sqlite3_bind_text(budgetStmt, 4, (createdAt as NSString).utf8String, -1, nil)

        guard sqlite3_step(budgetStmt) == SQLITE_DONE else {
            print("❌ createUserAccount: budget insert failed: \(String(cString: sqlite3_errmsg(db)))")
            sqlite3_finalize(budgetStmt)
            execute("DELETE FROM users WHERE id = ?;", args: [userId.uuidString])
            return nil
        }
        sqlite3_finalize(budgetStmt)

        storePassword(password, for: normalizedEmail)
        setCurrentUser(id: userId)
        markSetupComplete(for: userId, isComplete: false)
        return userId
    }

    func signIn(email: String, password: String) -> Bool {
        let normalizedEmail = normalizeEmail(email)
        guard !normalizedEmail.isEmpty,
              let user = fetchUser(email: normalizedEmail),
              storedPassword(for: normalizedEmail) == password
        else { return false }

        setCurrentUser(id: user.id)
        return true
    }

    func signOut() {
        setCurrentUser(id: nil)
    }

    private func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func makeDisplayName(from email: String) -> String {
        let localPart = email.split(separator: "@").first.map(String.init) ?? "User"
        let cleaned = localPart.replacingOccurrences(of: ".", with: " ")
        return cleaned.isEmpty ? "User" : cleaned.capitalized
    }

    private func storedPasswords() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: Self.passwordStoreKey) as? [String: String] ?? [:]
    }

    private func storePassword(_ password: String, for email: String) {
        var passwords = storedPasswords()
        passwords[normalizeEmail(email)] = password
        UserDefaults.standard.set(passwords, forKey: Self.passwordStoreKey)
    }

    private func storePasswordIfMissing(_ password: String, for email: String) {
        let normalizedEmail = normalizeEmail(email)
        guard storedPassword(for: normalizedEmail) == nil else { return }
        storePassword(password, for: normalizedEmail)
    }

    private func storedPassword(for email: String) -> String? {
        storedPasswords()[normalizeEmail(email)]
    }
}
