import Foundation
import SQLite3

extension DatabaseManager {

    @discardableResult
    func insertReceipt(
        merchantName: String,
        totalAmount: Double,
        date: Date,
        note: String? = nil,
        transactionIds: Set<UUID> = []
    ) -> UUID? {
        guard let userId = currentUserIdString else { return nil }

        guard sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil) == SQLITE_OK else {
            print("insertReceipt: begin failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }

        let receiptId = UUID()
        let insertReceiptSQL = """
        INSERT INTO receipts (id, user_id, merchant_name, total_amount, date, note, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """

        var receiptStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertReceiptSQL, -1, &receiptStmt, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            print("insertReceipt: prepare failed")
            return nil
        }

        let receiptDate = databaseTimestampString(from: date)
        let createdAt = databaseTimestampString(from: Date())

        sqlite3_bind_text(receiptStmt, 1, (receiptId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(receiptStmt, 2, (userId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(receiptStmt, 3, (merchantName as NSString).utf8String, -1, nil)
        sqlite3_bind_double(receiptStmt, 4, totalAmount)
        sqlite3_bind_text(receiptStmt, 5, (receiptDate as NSString).utf8String, -1, nil)
        if let note, !note.isEmpty {
            sqlite3_bind_text(receiptStmt, 6, (note as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(receiptStmt, 6)
        }
        sqlite3_bind_text(receiptStmt, 7, (createdAt as NSString).utf8String, -1, nil)

        guard sqlite3_step(receiptStmt) == SQLITE_DONE else {
            sqlite3_finalize(receiptStmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            print("insertReceipt failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        sqlite3_finalize(receiptStmt)

        if !transactionIds.isEmpty {
            let insertJoinSQL = """
            INSERT INTO receipt_transactions (receipt_id, transaction_id)
            VALUES (?, ?);
            """

            var joinStmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertJoinSQL, -1, &joinStmt, nil) == SQLITE_OK else {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                print("insertReceipt: join prepare failed")
                return nil
            }

            for transactionId in transactionIds {
                sqlite3_bind_text(joinStmt, 1, (receiptId.uuidString as NSString).utf8String, -1, nil)
                sqlite3_bind_text(joinStmt, 2, (transactionId.uuidString as NSString).utf8String, -1, nil)

                guard sqlite3_step(joinStmt) == SQLITE_DONE else {
                    sqlite3_finalize(joinStmt)
                    sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                    print("insertReceipt: join insert failed: \(String(cString: sqlite3_errmsg(db)))")
                    return nil
                }

                sqlite3_reset(joinStmt)
                sqlite3_clear_bindings(joinStmt)
            }

            sqlite3_finalize(joinStmt)
        }

        guard sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            print("insertReceipt: commit failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }

        return receiptId
    }
}
