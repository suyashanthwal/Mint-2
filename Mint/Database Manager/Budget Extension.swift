import Foundation
import SQLite3

extension DatabaseManager {

    func fetchCurrentBudget() -> Budget? {
        guard let userId = currentUserIdString else { return nil }

        let query = """
        SELECT id, allocated_budget, total_expense, daily_limit, last_reset_date
        FROM budgets
        WHERE user_id = ?
        LIMIT 1;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW,
              let idPtr = sqlite3_column_text(stmt, 0),
              let uuid  = UUID(uuidString: String(cString: idPtr))
        else { return nil }

        return Budget(
            id: uuid,
            allocatedBudget: sqlite3_column_double(stmt, 1),
            totalExpense: sqlite3_column_double(stmt, 2),
            dailyLimit: sqlite3_column_double(stmt, 3),
            lastResetDate: String(cString: sqlite3_column_text(stmt, 4)),
            categoryIds: fetchBudgetCategoryIds(budgetId: uuid)
        )
    }

    func fetchBudgetCategoryIds(budgetId: UUID) -> Set<UUID> {
        var ids = Set<UUID>()
        let query = "SELECT category_id FROM budget_categories WHERE budget_id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return ids }
        sqlite3_bind_text(stmt, 1, (budgetId.uuidString as NSString).utf8String, -1, nil)

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let ptr = sqlite3_column_text(stmt, 0),
               let uuid = UUID(uuidString: String(cString: ptr)) {
                ids.insert(uuid)
            }
        }
        sqlite3_finalize(stmt)
        return ids
    }

    func upsertCurrentBudget(allocatedBudget: Double) {
        guard let userId = currentUserIdString else {
            print("upsertCurrentBudget: no signed-in user")
            return
        }

        if fetchCurrentBudget() != nil {
            updateBudgetSettings(allocatedBudget: allocatedBudget)
            return
        }

        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        let dailyLimit = (allocatedBudget / Double(daysInMonth)).rounded(.down)

        let lastResetDate = databaseDateOnlyString(from: Date())
        let createdAt = databaseTimestampString(from: Date())

        let sql = """
        INSERT INTO budgets
            (id, user_id, allocated_budget, total_expense, daily_limit, last_reset_date, created_at)
        VALUES (?, ?, ?, 0, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("upsertCurrentBudget: prepare failed")
            return
        }

        let budgetId = UUID()
        sqlite3_bind_text(stmt, 1, (budgetId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (userId as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 3, allocatedBudget)
        sqlite3_bind_double(stmt, 4, dailyLimit)
        sqlite3_bind_text(stmt, 5, (lastResetDate as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 6, (createdAt as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_DONE {
            print("Budget created for user \(userId)")
        } else {
            print("upsertCurrentBudget failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
    }

    func updateBudgetSettings(allocatedBudget: Double, dailyLimit: Double? = nil) {
        guard let budget = fetchCurrentBudget() else {
            print("updateBudgetSettings: no budget found")
            return
        }

        let computed: Double
        if let explicit = dailyLimit {
            computed = explicit
        } else {
            let calendar = Calendar.current
            let days = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
            computed = (allocatedBudget / Double(days)).rounded(.down)
        }

        execute(
            "UPDATE budgets SET allocated_budget = ?, daily_limit = ? WHERE id = ?;",
            args: [String(allocatedBudget), String(computed), budget.id.uuidString]
        )
        print("Budget settings updated: ₹\(allocatedBudget), daily limit ₹\(computed)")
    }

    func addToMonthlyExpense(_ amount: Double) {
        guard let budget = fetchCurrentBudget() else { return }
        execute(
            "UPDATE budgets SET total_expense = total_expense + ? WHERE id = ?;",
            args: [String(amount), budget.id.uuidString]
        )
    }

    func subtractFromMonthlyExpense(_ amount: Double) {
        guard let budget = fetchCurrentBudget() else { return }
        execute(
            "UPDATE budgets SET total_expense = MAX(0, total_expense - ?) WHERE id = ?;",
            args: [String(amount), budget.id.uuidString]
        )
    }

    func checkAndResetMonthlyExpenseIfNeeded() {
        guard let budget = fetchCurrentBudget() else { return }

        let calendar  = Calendar.current
        let today     = Date()
        let nowYear   = calendar.component(.year,  from: today)
        let nowMonth  = calendar.component(.month, from: today)

        let parts      = budget.lastResetDate.split(separator: "-").compactMap { Int($0) }
        let resetYear  = parts.count >= 1 ? parts[0] : 0
        let resetMonth = parts.count >= 2 ? parts[1] : 0

        guard nowYear != resetYear || nowMonth != resetMonth else { return }

        resetMonthlyExpense()
    }

    func resetMonthlyExpense() {
        guard let budget = fetchCurrentBudget() else { return }

        let calendar = Calendar.current
        let now = Date()
        let monthTotal = fetchTransactions()
            .filter {
                $0.type == .expense &&
                calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.amount }

        let resetDateStr = databaseDateOnlyString(from: now)

        execute(
            "UPDATE budgets SET total_expense = ?, last_reset_date = ? WHERE id = ?;",
            args: [String(monthTotal), resetDateStr, budget.id.uuidString]
        )
        print("Monthly budget reset: total_expense = ₹\(monthTotal), last_reset_date = \(resetDateStr)")
    }
}
