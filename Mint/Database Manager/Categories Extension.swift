import Foundation
import SQLite3

extension DatabaseManager {

    func fetchCategories() -> [Category] {
        var result: [Category] = []

        guard let userId = currentUserIdString else { return result }

        let calendar = Calendar.current
        let now = Date()
        let currentMonthSpentByCategory = fetchTransactions()
            .filter {
                $0.type == .expense &&
                $0.categoryId != nil &&
                calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month)
            }
            .reduce(into: [UUID: Double]()) { partialResult, transaction in
                guard let categoryId = transaction.categoryId else { return }
                partialResult[categoryId, default: 0] += transaction.amount
            }

        let query = """
        SELECT id, name, color, icon, budget, type
        FROM categories
        WHERE user_id = ?
        ORDER BY created_at ASC;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return result }
        sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr   = String(cString: sqlite3_column_text(stmt, 0))
            let name    = String(cString: sqlite3_column_text(stmt, 1))
            let color   = String(cString: sqlite3_column_text(stmt, 2))
            let icon    = String(cString: sqlite3_column_text(stmt, 3))
            let budget  = sqlite3_column_double(stmt, 4)
            let typeStr = String(cString: sqlite3_column_text(stmt, 5))

            guard let uuid = UUID(uuidString: idStr) else { continue }
            let spent = currentMonthSpentByCategory[uuid] ?? 0
            let remaining = budget - spent
            let percentageUsed = budget > 0 ? spent / budget : 0

            result.append(Category(
                id: uuid,
                name: name,
                color: color,
                icon: icon,
                budget: budget,
                type: CategoryType(rawValue: typeStr) ?? .expense,
                remaining: remaining,
                isOver: remaining < 0,
                percentageUsed: percentageUsed
            ))
        }

        sqlite3_finalize(stmt)
        return result
    }

    func fetchCategory(named name: String) -> Category? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty,
              let userId = currentUserIdString
        else { return nil }

        let query = """
        SELECT id, name, color, icon, budget, type
        FROM categories
        WHERE user_id = ? AND lower(name) = lower(?)
        LIMIT 1;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (normalizedName as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        let idStr   = String(cString: sqlite3_column_text(stmt, 0))
        let name    = String(cString: sqlite3_column_text(stmt, 1))
        let color   = String(cString: sqlite3_column_text(stmt, 2))
        let icon    = String(cString: sqlite3_column_text(stmt, 3))
        let budget  = sqlite3_column_double(stmt, 4)
        let typeStr = String(cString: sqlite3_column_text(stmt, 5))

        guard let uuid = UUID(uuidString: idStr) else { return nil }

        return Category(
            id: uuid,
            name: name,
            color: color,
            icon: icon,
            budget: budget,
            type: CategoryType(rawValue: typeStr) ?? .expense
        )
    }

    @discardableResult
    func insertCategory(
        name: String,
        color: String,
        icon: String,
        budget: Double,
        type: CategoryType = .expense
    ) -> UUID? {
        let query = """
        INSERT INTO categories (id, user_id, name, color, icon, budget, type, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("insertCategory: prepare failed")
            return nil
        }

        let newId     = UUID()
        guard let userId = currentUserIdString else {
            sqlite3_finalize(stmt)
            print("insertCategory: no signed-in user")
            return nil
        }
        let createdAt = databaseTimestampString(from: Date())

        sqlite3_bind_text(stmt,   1, (newId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   2, (userId           as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   3, (name             as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   4, (color            as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   5, (icon             as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 6, budget)
        sqlite3_bind_text(stmt,   7, (type.rawValue    as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   8, (createdAt        as NSString).utf8String, -1, nil)

        let success = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)

        if success {
            print("Category inserted: \(name) (\(newId))")
            return newId
        } else {
            print("insertCategory failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
    }

    @discardableResult
    func ensureCategory(
        name: String,
        color: String,
        icon: String,
        budget: Double = 0,
        type: CategoryType = .expense
    ) -> UUID? {
        if let existing = fetchCategory(named: name) {
            return existing.id
        }
        return insertCategory(name: name, color: color, icon: icon, budget: budget, type: type)
    }

    func linkCategoryToCurrentBudget(categoryId: UUID) {
        guard let budget = fetchCurrentBudget() else {
            print("linkCategoryToCurrentBudget: no budget found")
            return
        }
        execute(
            "INSERT OR IGNORE INTO budget_categories (budget_id, category_id) VALUES (?, ?);",
            args: [budget.id.uuidString, categoryId.uuidString]
        )
        print("Linked category \(categoryId) → budget \(budget.id)")
    }

    func updateCategory(id: UUID, name: String, color: String, icon: String, budget: Double) {
        let query = """
        UPDATE categories
        SET name = ?, color = ?, icon = ?, budget = ?
        WHERE id = ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("updateCategory: prepare failed")
            return
        }
        sqlite3_bind_text(stmt,   1, (name          as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   2, (color         as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   3, (icon          as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, budget)
        sqlite3_bind_text(stmt,   5, (id.uuidString as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_DONE {
            print("Category updated: \(name)")
        } else {
            print("updateCategory failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
    }

    func deleteCategory(id: UUID) {
        execute("DELETE FROM categories WHERE id = ?;", args: [id.uuidString])
    }

    func deleteAllCategoriesForCurrentUser() {
        guard let userId = currentUserIdString else { return }
        execute("DELETE FROM categories WHERE user_id = ?;", args: [userId])
    }
}
