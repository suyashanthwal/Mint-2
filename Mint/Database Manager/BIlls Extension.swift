import Foundation
import SQLite3

extension DatabaseManager {

    func fetchBills() -> [Bill] {
        var result: [Bill] = []
        guard let userId = currentUserIdString else { return result }

        let query = """
        SELECT id, name, amount, bill_date, is_paid, icon, category_id, range,
               is_alert_enabled, note
        FROM bills
        WHERE user_id = ?
        ORDER BY bill_date ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return result }
        sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)

        while sqlite3_step(stmt) == SQLITE_ROW {
            func optText(_ col: Int32) -> String? {
                guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
                let s = String(cString: ptr); return s.isEmpty ? nil : s
            }
            guard let idPtr = sqlite3_column_text(stmt, 0),
                  let uuid  = UUID(uuidString: String(cString: idPtr)) else { continue }

            let name           = String(cString: sqlite3_column_text(stmt, 1))
            let amount         = sqlite3_column_double(stmt, 2)
            let dateStr        = String(cString: sqlite3_column_text(stmt, 3))
            let date           = databaseDate(from: dateStr) ?? .distantPast
            let isPaid         = sqlite3_column_int(stmt, 4) == 1
            let icon           = String(cString: sqlite3_column_text(stmt, 5))
            let catStr         = String(cString: sqlite3_column_text(stmt, 6))
            let rangeStr       = String(cString: sqlite3_column_text(stmt, 7))
            let isAlertEnabled = sqlite3_column_int(stmt, 8) == 1
            let note           = optText(9)

            result.append(Bill(
                id: uuid,
                name: name,
                icon: icon,
                categoryId: UUID(uuidString: catStr) ?? UUID(),
                amount: amount,
                billDate: date,
                range: BillingRange(rawValue: rangeStr) ?? .monthly,
                isPaid: isPaid,
                isAlertEnabled: isAlertEnabled,
                note: note
            ))
        }

        sqlite3_finalize(stmt)
        return result.sorted { $0.billDate < $1.billDate }
    }

    func fetchBill(id: UUID) -> Bill? {
        fetchBills().first { $0.id == id }
    }

    func fetchUpcomingBills() -> [Bill] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return fetchBills()
            .filter { !$0.isPaid && $0.billDate >= startOfToday }
            .sorted { $0.billDate < $1.billDate }
    }

    @discardableResult
    func insertBill(
        name: String,
        icon: String,
        categoryId: UUID,
        amount: Double,
        billDate: Date,
        range: BillingRange,
        isAlertEnabled: Bool = true,
        note: String?
    ) -> UUID? {
        let query = """
        INSERT INTO bills
            (id, user_id, name, icon, category_id, amount, bill_date,
             range, is_paid, is_alert_enabled, note, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ insertBill: prepare failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }

        let newId     = UUID()
        guard let userId = currentUserIdString else {
            sqlite3_finalize(stmt)
            print("⚠️ insertBill: no signed-in user")
            return nil
        }
        let dateStr   = databaseTimestampString(from: billDate)
        let createdAt = databaseTimestampString(from: Date())

        sqlite3_bind_text(stmt,   1, (newId.uuidString      as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   2, (userId                as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   3, (name                  as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   4, (icon                  as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   5, (categoryId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 6, amount)
        sqlite3_bind_text(stmt,   7, (dateStr               as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   8, (range.rawValue        as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt,    9, isAlertEnabled ? 1 : 0)
        if let note = note, !note.isEmpty {
            sqlite3_bind_text(stmt, 10, (note as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 10)
        }
        sqlite3_bind_text(stmt, 11, (createdAt as NSString).utf8String, -1, nil)

        let success = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)

        if success {
            print("✅ Bill inserted: \(name) (\(newId))")
            return newId
        } else {
            print("❌ insertBill failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
    }

    func updateBill(
        id: UUID,
        name: String,
        amount: Double,
        billDate: Date,
        range: BillingRange,
        note: String?
    ) {
        let query = """
        UPDATE bills
        SET name = ?, amount = ?, bill_date = ?, range = ?, note = ?
        WHERE id = ?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ updateBill: prepare failed")
            return
        }

        let dateStr = databaseTimestampString(from: billDate)

        sqlite3_bind_text(stmt,   1, (name          as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 2, amount)
        sqlite3_bind_text(stmt,   3, (dateStr        as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt,   4, (range.rawValue as NSString).utf8String, -1, nil)
        if let note = note, !note.isEmpty {
            sqlite3_bind_text(stmt, 5, (note as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_text(stmt, 6, (id.uuidString as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_DONE {
            print("✅ Bill updated: \(name)")
        } else {
            print("❌ updateBill failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
    }

    func updateBillPaymentStatus(id: UUID, isPaid: Bool) {
        execute(
            "UPDATE bills SET is_paid = ? WHERE id = ?;",
            args: [isPaid ? "1" : "0", id.uuidString]
        )
    }

    func deleteBill(id: UUID) {
        execute("DELETE FROM bills WHERE id = ?;", args: [id.uuidString])
    }

    func deleteAllBillsForCurrentUser() {
        guard let userId = currentUserIdString else { return }
        execute("DELETE FROM bills WHERE user_id = ?;", args: [userId])
    }
}
