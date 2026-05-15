import Foundation
import SQLite3

extension DatabaseManager {

    func fetchGoals() -> [Goal] {
        var result: [Goal] = []
        guard let userId = currentUserIdString else { return result }

        let query = """
        SELECT id,
               name,
               target_amount,
               currently_saved,
               target_date,
               monthly_goal,
               icon_name,
               image_name,
               is_completed,
               is_on_hold,
               completed_on
        FROM goals
        WHERE user_id = ?
        ORDER BY is_completed ASC, is_on_hold ASC, target_date ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return result }
        sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)

        let iso = ISO8601DateFormatter()

        func optionalText(_ col: Int32) -> String? {
            guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
            let value = String(cString: ptr)
            return value.isEmpty ? nil : value
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let idPtr = sqlite3_column_text(stmt, 0),
                let uuid = UUID(uuidString: String(cString: idPtr))
            else { continue }

            let targetDate = iso.date(from: String(cString: sqlite3_column_text(stmt, 4))) ?? Date()
            let completedOn = optionalText(10).flatMap { iso.date(from: $0) }

            result.append(Goal(
                id: uuid,
                name: String(cString: sqlite3_column_text(stmt, 1)),
                targetAmount: sqlite3_column_double(stmt, 2),
                currentlySaved: sqlite3_column_double(stmt, 3),
                targetDate: targetDate,
                monthlyGoal: sqlite3_column_double(stmt, 5),
                iconName: String(cString: sqlite3_column_text(stmt, 6)),
                imageName: optionalText(7),
                isCompleted: sqlite3_column_int(stmt, 8) == 1,
                isOnHold: sqlite3_column_int(stmt, 9) == 1,
                completedOn: completedOn
            ))
        }

        sqlite3_finalize(stmt)
        return result
    }

    func fetchGoal(id: UUID) -> Goal? {
        fetchGoals().first { $0.id == id }
    }

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
            (id,
             user_id,
             name,
             target_amount,
             currently_saved,
             target_date,
             monthly_goal,
             icon_name,
             image_name,
             is_completed,
             is_on_hold,
             completed_on,
             created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("insertGoal: prepare failed")
            return nil
        }

        let newId = UUID()
        let iso = ISO8601DateFormatter()

        guard let userId = currentUserIdString else {
            sqlite3_finalize(stmt)
            print("insertGoal: no signed-in user")
            return nil
        }

        let createdAt = iso.string(from: Date())

        sqlite3_bind_text(stmt, 1, (newId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (userId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, targetAmount)
        sqlite3_bind_double(stmt, 5, 0)
        sqlite3_bind_text(stmt, 6, (iso.string(from: targetDate) as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 7, monthlyGoal)
        sqlite3_bind_text(stmt, 8, (iconName as NSString).utf8String, -1, nil)

        if let imageName {
            sqlite3_bind_text(stmt, 9, (imageName as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 9)
        }

        sqlite3_bind_int(stmt, 10, 0)
        sqlite3_bind_int(stmt, 11, 0)
        sqlite3_bind_null(stmt, 12)
        sqlite3_bind_text(stmt, 13, (createdAt as NSString).utf8String, -1, nil)

        let success = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)

        if success {
            print("Goal inserted: \(name)")
            return newId
        } else {
            print("insertGoal failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
    }

    func linkGoalToCurrentBudget(goalId: UUID) {
        guard let budget = fetchCurrentBudget() else {
            print("linkGoalToCurrentBudget: no budget found")
            return
        }

        print("Goal \(goalId) is available to budget \(budget.id) through the shared user scope")
    }

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
        isOnHold: Bool = false,
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
            is_on_hold      = ?,
            completed_on    = ?
        WHERE id = ?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("updateGoal: prepare failed")
            return
        }

        let iso = ISO8601DateFormatter()

        sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 2, targetAmount)
        sqlite3_bind_double(stmt, 3, currentlySaved)
        sqlite3_bind_text(stmt, 4, (iso.string(from: targetDate) as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 5, monthlyGoal)
        sqlite3_bind_text(stmt, 6, (iconName as NSString).utf8String, -1, nil)

        if let imageName {
            sqlite3_bind_text(stmt, 7, (imageName as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 7)
        }

        sqlite3_bind_int(stmt, 8, isCompleted ? 1 : 0)
        sqlite3_bind_int(stmt, 9, isOnHold ? 1 : 0)

        if let completedOn {
            sqlite3_bind_text(stmt, 10, (iso.string(from: completedOn) as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 10)
        }

        sqlite3_bind_text(stmt, 11, (id.uuidString as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_DONE {
            print("Goal updated: \(name)")
        } else {
            print("updateGoal failed: \(String(cString: sqlite3_errmsg(db)))")
        }

        sqlite3_finalize(stmt)
    }

    @discardableResult
    func addMoneyToGoal(goalId: UUID, amount: Double) -> Bool {
        guard amount > 0, var goal = fetchGoal(id: goalId) else { return false }

        goal.currentlySaved = min(goal.currentlySaved + amount, goal.targetAmount)

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
            isOnHold: goal.isOnHold,
            completedOn: goal.completedOn
        )

        return true
    }

    @discardableResult
    func setGoalHoldState(id: UUID, isOnHold: Bool) -> Bool {
        guard var goal = fetchGoal(id: id) else { return false }
        guard !goal.isCompleted else { return false }

        goal.isOnHold = isOnHold

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
            isOnHold: goal.isOnHold,
            completedOn: goal.completedOn
        )

        return true
    }

    @discardableResult
    func markGoalPurchased(id: UUID) -> Bool {
        guard var goal = fetchGoal(id: id) else { return false }
        guard goal.currentlySaved >= goal.targetAmount else { return false }

        goal.currentlySaved = min(goal.currentlySaved, goal.targetAmount)
        goal.isCompleted = true
        goal.isOnHold = false
        goal.completedOn = goal.completedOn ?? Date()

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
            isOnHold: goal.isOnHold,
            completedOn: goal.completedOn
        )

        return true
    }

    func deleteGoal(id: UUID) {
        execute("DELETE FROM goals WHERE id = ?;", args: [id.uuidString])
    }
}
