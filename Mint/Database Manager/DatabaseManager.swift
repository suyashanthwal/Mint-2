import Foundation
import SQLite3

final class DatabaseManager {

    enum AuthenticationProvider: String {
        case emailPassword
        case apple
    }

    static let shared = DatabaseManager()
    static let defaultAdminUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let currentDefaultAdminSeedVersion = 5

    private static let currentUserIdKey = "current_user_id"
    private static let currentAuthProviderKey = "current_auth_provider"
    private static let currentAppleUserIdentifierKey = "current_apple_user_identifier"
    private static let setupCompletedUserIdsKey = "setup_completed_user_ids"
    private static let defaultAdminSeedVersionKey = "default_admin_seed_version"
    private static let databaseDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
    private static let databaseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private static let iso8601FractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    var db: OpaquePointer?

    private init() {
        let databaseExists = FileManager.default.fileExists(atPath: getDBPath())
        openDatabase()
        setupDatabase(forceInitialize: !databaseExists)
        clearInvalidCurrentSessionIfNeeded()
    }

    private func getDBPath() -> String {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return url.appendingPathComponent("mint.sqlite").path
    }

    func documentsDirectoryURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func databaseFileURL() -> URL {
        URL(fileURLWithPath: getDBPath())
    }

    func databaseSupportFileURLs() -> [URL] {
        let databaseURL = databaseFileURL()
        return [
            databaseURL,
            URL(fileURLWithPath: databaseURL.path + "-wal"),
            URL(fileURLWithPath: databaseURL.path + "-shm")
        ]
    }

    private func openDatabase() {
        if sqlite3_open(getDBPath(), &db) != SQLITE_OK {
            print("Error opening DB")
        } else {
            sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
            print("DB opened at \(getDBPath())")
        }
    }

    private func setupDatabase(forceInitialize: Bool = false) {
        let isFirstLaunch = forceInitialize || !UserDefaults.standard.bool(forKey: "db_initialized")
        if isFirstLaunch {
            runSQLFile(named: "schema")
            runSQLFile(named: "seed")
            UserDefaults.standard.set(true, forKey: "db_initialized")
            UserDefaults.standard.set(
                Self.currentDefaultAdminSeedVersion,
                forKey: Self.defaultAdminSeedVersionKey
            )
        }
        ensureGoalsOnHoldColumnExists()
        ensureDefaultAdminAccountState()
        ensureDefaultAdminSeedDataIsCurrent()
        checkAndResetMonthlyExpenseIfNeeded()
    }

    func resetDatabase() {
        sqlite3_close(db)
        db = nil

        try? FileManager.default.removeItem(atPath: getDBPath())

        openDatabase()
        runSQLFile(named: "schema")
        runSQLFile(named: "seed")
        ensureDefaultAdminAccountState()

        UserDefaults.standard.set(true, forKey: "db_initialized")
        UserDefaults.standard.set(
            Self.currentDefaultAdminSeedVersion,
            forKey: Self.defaultAdminSeedVersionKey
        )
        setCurrentUser(id: nil)
        print("DB reset complete")
    }

    func checkpointForBackup() {
        guard let db else { return }
        sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil)
    }

    @discardableResult
    func replaceDatabaseFiles(with urls: [URL]) -> Bool {
        sqlite3_close(db)
        db = nil

        let fileManager = FileManager.default
        let localURLs = databaseSupportFileURLs()

        do {
            for localURL in localURLs where fileManager.fileExists(atPath: localURL.path) {
                try fileManager.removeItem(at: localURL)
            }

            for sourceURL in urls where fileManager.fileExists(atPath: sourceURL.path) {
                let destinationURL = documentsDirectoryURL().appendingPathComponent(sourceURL.lastPathComponent)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }

            openDatabase()
            setupDatabase(forceInitialize: false)
            clearInvalidCurrentSessionIfNeeded()
            return true
        } catch {
            print("replaceDatabaseFiles failed: \(error)")
            openDatabase()
            return false
        }
    }

    func countNonAdminUsers() -> Int {
        let query = "SELECT COUNT(*) FROM users WHERE id != ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (Self.defaultAdminUserId.uuidString as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    func runSQLFile(named fileName: String) {
        guard let path = Bundle.main.path(forResource: fileName, ofType: "sql") else {
            print("SQL file not found: \(fileName).sql")
            return
        }
        do {
            let sql = try String(contentsOfFile: path, encoding: .utf8)
            if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                print("SQL error in \(fileName): \(String(cString: sqlite3_errmsg(db)))")
            } else {
                print("Executed \(fileName).sql")
            }
        } catch {
            print("Could not read \(fileName).sql: \(error)")
        }
    }

    func executeStatements(_ sql: String) {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            print("SQL exec failed: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    func execute(_ sql: String, args: [String]) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("Prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return
        }
        for (i, arg) in args.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), (arg as NSString).utf8String, -1, nil)
        }
        if sqlite3_step(stmt) != SQLITE_DONE {
            print("Execute failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
    }

    var currentUserId: UUID? {
        guard let id = UserDefaults.standard.string(forKey: Self.currentUserIdKey) else { return nil }
        return UUID(uuidString: id)
    }

    var currentUserIdString: String? {
        currentUserId?.uuidString
    }

    var currentAuthenticationProvider: AuthenticationProvider? {
        guard let rawValue = UserDefaults.standard.string(forKey: Self.currentAuthProviderKey) else {
            return nil
        }
        return AuthenticationProvider(rawValue: rawValue)
    }

    var currentAppleUserIdentifier: String? {
        UserDefaults.standard.string(forKey: Self.currentAppleUserIdentifierKey)
    }

    var hasActiveSession: Bool {
        guard let currentUserId else { return false }
        return fetchUser(id: currentUserId) != nil
    }

    func setCurrentUser(id: UUID?) {
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: Self.currentUserIdKey)
            checkAndResetMonthlyExpenseIfNeeded()
        } else {
            UserDefaults.standard.removeObject(forKey: Self.currentUserIdKey)
            UserDefaults.standard.removeObject(forKey: Self.currentAuthProviderKey)
            UserDefaults.standard.removeObject(forKey: Self.currentAppleUserIdentifierKey)
        }
    }

    func setCurrentAuthentication(provider: AuthenticationProvider?, appleUserIdentifier: String? = nil) {
        if let provider {
            UserDefaults.standard.set(provider.rawValue, forKey: Self.currentAuthProviderKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.currentAuthProviderKey)
        }

        if let appleUserIdentifier, provider == .apple {
            UserDefaults.standard.set(appleUserIdentifier, forKey: Self.currentAppleUserIdentifierKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.currentAppleUserIdentifierKey)
        }
    }

    private func clearInvalidCurrentSessionIfNeeded() {
        guard let currentUserId, fetchUser(id: currentUserId) == nil else { return }
        setCurrentUser(id: nil)
        markSetupComplete(for: currentUserId, isComplete: false)
    }

    func markSetupComplete(for userId: UUID, isComplete: Bool) {
        var ids = Set(UserDefaults.standard.stringArray(forKey: Self.setupCompletedUserIdsKey) ?? [])
        if isComplete {
            ids.insert(userId.uuidString)
        } else {
            ids.remove(userId.uuidString)
        }
        UserDefaults.standard.set(Array(ids), forKey: Self.setupCompletedUserIdsKey)
    }

    func isSetupComplete(for userId: UUID) -> Bool {
        let ids = Set(UserDefaults.standard.stringArray(forKey: Self.setupCompletedUserIdsKey) ?? [])
        return ids.contains(userId.uuidString)
    }

    func isCurrentUserSetupComplete() -> Bool {
        guard let currentUserId else { return false }
        return isSetupComplete(for: currentUserId)
    }

    func storedDefaultAdminSeedVersion() -> Int {
        UserDefaults.standard.integer(forKey: Self.defaultAdminSeedVersionKey)
    }

    func markDefaultAdminSeedVersionCurrent() {
        UserDefaults.standard.set(
            Self.currentDefaultAdminSeedVersion,
            forKey: Self.defaultAdminSeedVersionKey
        )
    }

    func databaseTimestampString(from date: Date) -> String {
        Self.databaseDateTimeFormatter.string(from: date)
    }

    func databaseDateOnlyString(from date: Date) -> String {
        Self.databaseDateFormatter.string(from: date)
    }

    func databaseDate(from rawValue: String) -> Date? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let parsed = Self.iso8601FractionalFormatter.date(from: value) {
            return parsed
        }
        if let parsed = Self.iso8601Formatter.date(from: value) {
            return parsed
        }
        if let parsed = Self.databaseDateTimeFormatter.date(from: value) {
            return parsed
        }
        return Self.databaseDateFormatter.date(from: value)
    }

    private func ensureGoalsOnHoldColumnExists() {
        guard let db else { return }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(goals);", -1, &stmt, nil) == SQLITE_OK else {
            return
        }

        var hasOnHoldColumn = false

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let columnName = sqlite3_column_text(stmt, 1) else { continue }
            if String(cString: columnName) == "is_on_hold" {
                hasOnHoldColumn = true
                break
            }
        }

        sqlite3_finalize(stmt)

        guard !hasOnHoldColumn else { return }

        let alterTable = "ALTER TABLE goals ADD COLUMN is_on_hold INTEGER NOT NULL DEFAULT 0;"
        if sqlite3_exec(db, alterTable, nil, nil, nil) != SQLITE_OK {
            print("Failed to add goals.is_on_hold column: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

}
