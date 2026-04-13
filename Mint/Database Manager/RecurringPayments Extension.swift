import Foundation
import SQLite3

extension DatabaseManager {

    func fetchRecurringPayments() -> [RecurringPayment] {
        var result: [RecurringPayment] = []
        guard let userId = currentUserIdString else { return result }

        let query = """
        SELECT id, name, category_id, duration, amount, next_date, last_date,
               is_active, is_alert_enabled, is_add_automatically,
               repeat_count, total_amount, icon, note, is_income
        FROM recurring_payments
        WHERE user_id = ?
        ORDER BY next_date ASC;
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

            let duration = PaymentDuration(rawValue: String(cString: sqlite3_column_text(stmt, 3))) ?? .monthly

            result.append(RecurringPayment(
                id: uuid,
                name: String(cString: sqlite3_column_text(stmt, 1)),
                categoryId: optText(2).flatMap { UUID(uuidString: $0) },
                duration: duration,
                amount: sqlite3_column_double(stmt, 4),
                nextDate: iso.date(from: String(cString: sqlite3_column_text(stmt, 5))) ?? Date(),
                isActive: sqlite3_column_int(stmt, 7) == 1,
                isAlertEnabled: sqlite3_column_int(stmt, 8) == 1,
                isAddAutomatically: sqlite3_column_int(stmt, 9) == 1,
                repeatCount: Int(sqlite3_column_int(stmt, 10)),
                totalAmount: sqlite3_column_double(stmt, 11),
                icon: optText(12),
                note: optText(13),
                isIncome: sqlite3_column_int(stmt, 14) == 1,
                lastDate: optText(6).flatMap { iso.date(from: $0) }
            ))
        }

        sqlite3_finalize(stmt)
        return result
    }

    @discardableResult
    func insertRecurringPayment(
        name: String,
        categoryId: UUID?,
        duration: PaymentDuration,
        amount: Double,
        nextDate: Date,
        icon: String? = nil,
        isAlertEnabled: Bool,
        isAddAutomatically: Bool,
        note: String?
    ) -> UUID? {
        let query = """
        INSERT INTO recurring_payments
            (id, user_id, name, category_id, duration, amount, next_date,
             is_active, is_alert_enabled, is_add_automatically,
             repeat_count, total_amount, icon, is_income, note)
        VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, 0, 0, ?, 0, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ insertRecurringPayment: prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }

        let newId   = UUID()
        guard let userId = currentUserIdString else {
            sqlite3_finalize(stmt)
            print("⚠️ insertRecurringPayment: no signed-in user")
            return nil
        }
        let nextStr = ISO8601DateFormatter().string(from: nextDate)

        sqlite3_bind_text(stmt, 1, (newId.uuidString  as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (userId            as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (name              as NSString).utf8String, -1, nil)
        if let catId = categoryId {
            sqlite3_bind_text(stmt, 4, (catId.uuidString as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        sqlite3_bind_text(stmt,   5, (duration.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 6, amount)
        sqlite3_bind_text(stmt,   7, (nextStr           as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt,    8, isAlertEnabled     ? 1 : 0)
        sqlite3_bind_int(stmt,    9, isAddAutomatically ? 1 : 0)
        if let icon, !icon.isEmpty {
            sqlite3_bind_text(stmt, 10, (icon as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 10)
        }
        if let note = note, !note.isEmpty {
            sqlite3_bind_text(stmt, 11, (note as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 11)
        }

        let success = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)

        if success {
            print("✅ RecurringPayment inserted: \(name) (\(newId))")
            return newId
        } else {
            print("❌ insertRecurringPayment failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
    }

    func updateRecurringPayment(
        id: UUID,
        name: String,
        duration: PaymentDuration,
        amount: Double,
        nextDate: Date,
        isAlertEnabled: Bool,
        isAddAutomatically: Bool,
        isActive: Bool,
        note: String?
    ) {
        let query = """
        UPDATE recurring_payments
        SET name = ?, duration = ?, amount = ?, next_date = ?,
            is_alert_enabled = ?, is_add_automatically = ?, is_active = ?, note = ?
        WHERE id = ?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ updateRecurringPayment: prepare failed")
            return
        }

        let nextStr = ISO8601DateFormatter().string(from: nextDate)

        sqlite3_bind_text(stmt,   1, (name              as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   2, (duration.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 3, amount)
        sqlite3_bind_text(stmt,   4, (nextStr           as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt,    5, isAlertEnabled     ? 1 : 0)
        sqlite3_bind_int(stmt,    6, isAddAutomatically ? 1 : 0)
        sqlite3_bind_int(stmt,    7, isActive           ? 1 : 0)
        if let note = note, !note.isEmpty {
            sqlite3_bind_text(stmt, 8, (note as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 8)
        }
        sqlite3_bind_text(stmt, 9, (id.uuidString as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_DONE {
            print("✅ RecurringPayment updated: \(name)")
        } else {
            print("❌ updateRecurringPayment failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
    }

    func deleteRecurringPayment(id: UUID) {
        execute("DELETE FROM recurring_payments WHERE id = ?;", args: [id.uuidString])
    }

    func deleteAllRecurringPaymentsForCurrentUser() {
        guard let userId = currentUserIdString else { return }
        execute("DELETE FROM recurring_payments WHERE user_id = ?;", args: [userId])
    }
}
