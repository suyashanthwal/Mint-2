import Foundation
import SQLite3

extension DatabaseManager {

    // MARK: - Fetch Goals

    func fetchGoals() -> [Goal] {
        var result: [Goal] = []
        guard let userId = currentUserIdString else { return result }

        let query = """
        SELECT id, name, target_amount, currently_saved, target_date,
               monthly_goal, icon_name, image_name, is_completed, completed_on
        FROM goals
        WHERE user_id = ?
        ORDER BY is_completed ASC, target_date ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return result }
        sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)

        let iso = ISO8601DateFormatter()

        func optText(_ col: Int32) -> String? {
            guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
            let s = String(cString: ptr)
            return s.isEmpty ? nil : s
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let idPtr = sqlite3_column_text(stmt, 0),
                let uuid  = UUID(uuidString: String(cString: idPtr))
            else { continue }

            result.append(Goal(
                id:             uuid,
                name:           String(cString: sqlite3_column_text(stmt, 1)),
                targetAmount:   sqlite3_column_double(stmt, 2),
                currentlySaved: sqlite3_column_double(stmt, 3),
                targetDate:     iso.date(from: String(cString: sqlite3_column_text(stmt, 4))) ?? Date(),
                monthlyGoal:    sqlite3_column_double(stmt, 5),
                iconName:       String(cString: sqlite3_column_text(stmt, 6)),
                imageName:      optText(7),
                isCompleted:    sqlite3_column_int(stmt, 8) == 1,
                completedOn:    optText(9).flatMap { iso.date(from: $0) }
            ))
        }

        sqlite3_finalize(stmt)
        return result
    }

    func fetchGoal(id: UUID) -> Goal? {
        fetchGoals().first { $0.id == id }
    }

    // MARK: - Insert Goal

    @discardableResult
    func insertGoal(
        name: String,
        targetAmount: Double,
        targetDate: Date,
        monthlyGoal: Double,
        iconName: String,
        imageName: String? = nil
    ) -> UUID? {

        let sql = """
        INSERT INTO goals
            (id, user_id, name, target_amount, currently_saved, target_date,
             monthly_goal, icon_name, image_name, is_completed, completed_on, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ insertGoal: prepare failed")
            return nil
        }

        let newId = UUID()
        let iso   = ISO8601DateFormatter()

        guard let userId = currentUserIdString else {
            sqlite3_finalize(stmt)
            print("⚠️ insertGoal: no signed-in user")
            return nil
        }
        let createdAt = iso.string(from: Date()) // 🔥 current time

        sqlite3_bind_text(stmt, 1, (newId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (userId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, targetAmount)
        sqlite3_bind_double(stmt, 5, 0)
        sqlite3_bind_text(stmt, 6, (iso.string(from: targetDate) as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 7, monthlyGoal)
        sqlite3_bind_text(stmt, 8, (iconName as NSString).utf8String, -1, nil)

        if let img = imageName {
            sqlite3_bind_text(stmt, 9, (img as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 9)
        }

        sqlite3_bind_int(stmt, 10, 0) // is_completed
        sqlite3_bind_null(stmt, 11)   // completed_on
        sqlite3_bind_text(stmt, 12, (createdAt as NSString).utf8String, -1, nil) // 🔥 NEW

        let success = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)

        if success {
            print("✅ Goal inserted: \(name)")
            return newId
        } else {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ insertGoal failed: \(error)")
            return nil
        }
    }
    // MARK: - Link Goal to Budget

    func linkGoalToCurrentBudget(goalId: UUID) {
        guard let budget = fetchCurrentBudget() else {
            print("⚠️ linkGoalToCurrentBudget: no budget found")
            return
        }

        // Goals are currently scoped by user_id in the schema, and there is no
        // budget_goals join table yet. Keep this as a harmless no-op so callers
        // can continue saving goals without triggering SQL errors.
        print("ℹ️ Goal \(goalId) is available to budget \(budget.id) through the shared user scope")
    }

    // MARK: - Update Goal

    func updateGoal(
        id: UUID,
        name: String,
        targetAmount: Double,
        currentlySaved: Double,
        targetDate: Date,
        monthlyGoal: Double,
        iconName: String,
        imageName: String? = nil,
        isCompleted: Bool = false,
        completedOn: Date? = nil
    ) {
        let sql = """
        UPDATE goals
        SET name            = ?,
            target_amount   = ?,
            currently_saved = ?,
            target_date     = ?,
            monthly_goal    = ?,
            icon_name       = ?,
            image_name      = ?,
            is_completed    = ?,
            completed_on    = ?
        WHERE id = ?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ updateGoal: prepare failed")
            return
        }

        let iso = ISO8601DateFormatter()

        sqlite3_bind_text(stmt,   1, (name                          as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 2, targetAmount)
        sqlite3_bind_double(stmt, 3, currentlySaved)
        sqlite3_bind_text(stmt,   4, (iso.string(from: targetDate)   as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 5, monthlyGoal)
        sqlite3_bind_text(stmt,   6, (iconName                       as NSString).utf8String, -1, nil)

        if let img = imageName {
            sqlite3_bind_text(stmt, 7, (img as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 7)
        }

        sqlite3_bind_int(stmt,  8, isCompleted ? 1 : 0)

        if let completed = completedOn {
            sqlite3_bind_text(stmt, 9, (iso.string(from: completed) as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 9)
        }

        sqlite3_bind_text(stmt, 10, (id.uuidString as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_DONE {
            print("✅ Goal updated: \(name)")
        } else {
            print("❌ updateGoal failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
    }

    @discardableResult
    func addMoneyToGoal(goalId: UUID, amount: Double) -> Bool {
        guard amount > 0, var goal = fetchGoal(id: goalId) else { return false }

        goal.currentlySaved += amount

        if goal.currentlySaved >= goal.targetAmount {
            goal.currentlySaved = goal.targetAmount
            goal.isCompleted = true
            goal.completedOn = goal.completedOn ?? Date()
        }

        updateGoal(
            id: goal.id,
            name: goal.name,
            targetAmount: goal.targetAmount,
            currentlySaved: goal.currentlySaved,
            targetDate: goal.targetDate,
            monthlyGoal: goal.monthlyGoal,
            iconName: goal.iconName,
            imageName: goal.imageName,
            isCompleted: goal.isCompleted,
            completedOn: goal.completedOn
        )

        return true
    }

    // MARK: - Delete Goal

    func deleteGoal(id: UUID) {
        execute("DELETE FROM goals WHERE id = ?;", args: [id.uuidString])
    }
}
