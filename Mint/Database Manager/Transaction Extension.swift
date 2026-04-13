import Foundation
import SQLite3

extension DatabaseManager {

    private func isCurrentMonth(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    private func billPaymentTransactionNote(for billId: UUID) -> String {
        "bill_payment:\(billId.uuidString)"
    }

    private func billId(fromBillPaymentNote note: String?) -> UUID? {
        guard let note,
              note.hasPrefix("bill_payment:")
        else { return nil }

        let identifier = String(note.dropFirst("bill_payment:".count))
        return UUID(uuidString: identifier)
    }

    func fetchTransactions(limit: Int? = nil) -> [Transaction] {
        var result: [Transaction] = []
        guard let userId = currentUserIdString else { return result }

        var query = """
        SELECT id, name, amount, timestamp, source, type,
               source_name, category_id, status, expense_type, note,
               upi_transaction_id, upi_merchant_name, upi_currency_type, created_at
        FROM transactions
        WHERE user_id = ?
        """
        query += ";"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ fetchTransactions: prepare failed")
            return result
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)

        while sqlite3_step(stmt) == SQLITE_ROW {
            func text(_ col: Int32) -> String {
                guard let ptr = sqlite3_column_text(stmt, col) else { return "" }
                return String(cString: ptr)
            }
            func optText(_ col: Int32) -> String? {
                guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
                let s = String(cString: ptr)
                return s.isEmpty ? nil : s
            }

            guard let id = UUID(uuidString: text(0)) else { continue }

            let name        = text(1)
            let amount      = sqlite3_column_double(stmt, 2)
            let timestampText = text(3)
            let createdAtText = optText(14)
            let timestamp   = databaseDate(from: timestampText)
                ?? createdAtText.flatMap { databaseDate(from: $0) }
                ?? .distantPast
            let createdAt   = createdAtText.flatMap { databaseDate(from: $0) }
                ?? timestamp
            let sourceStr   = text(4)
            let typeStr     = text(5)
            let sourceName  = optText(6)
            let categoryStr = optText(7)
            let statusInt   = sqlite3_column_type(stmt, 8) != SQLITE_NULL
                                ? sqlite3_column_int(stmt, 8) : -1
            let expenseType = optText(9)
            let note        = optText(10)
            let upiTxnId    = optText(11)
            let upiMerchant = optText(12)
            let upiCurrency = optText(13)

            let upiInfo: UPIInfo? = upiTxnId.map {
                UPIInfo(
                    upiTransactionId: $0,
                    merchantName: upiMerchant ?? "",
                    currencyType: upiCurrency ?? "INR"
                )
            }

            let source: TransactionSource = {
                switch sourceStr {
                case "upi":       return .upi
                case "receipt":   return .receipt
                case "ecommerce": return .ecommerce
                default:          return .manual
                }
            }()

            let categoryId = categoryStr.flatMap { UUID(uuidString: $0) }

            if typeStr == "income" {
                result.append(Transaction(
                    name: name,
                    amount: amount,
                    timestamp: timestamp,
                    id: id,
                    createdAt: createdAt,
                    sourceName: sourceName ?? "",
                    note: note
                ))
            } else {
                result.append(Transaction(
                    name: name,
                    amount: amount,
                    timestamp: timestamp,
                    id: id,
                    createdAt: createdAt,
                    categoryId: categoryId ?? UUID(),
                    status: statusInt == 1,
                    expenseType: expenseType ?? "",
                    source: source,
                    note: note,
                    upiInfo: upiInfo
                ))
            }
        }

        result.sort { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp > rhs.timestamp
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }

        if let limit {
            return Array(result.prefix(limit))
        }

        return result
    }

    func fetchRecentTransactions(limit: Int = 5) -> [Transaction] {
        let sortedTransactions = fetchTransactions().sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp > rhs.timestamp
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }

        return Array(sortedTransactions.prefix(limit))
    }

    func fetchBufferedTransactions(limit: Int? = nil) -> [BufferedTransaction] {
        var result: [BufferedTransaction] = []
        guard let userId = currentUserIdString else { return result }

        let query = """
        SELECT id, name, amount, timestamp, source, type,
               source_name, category_id, status, expense_type, note,
               upi_transaction_id, upi_merchant_name, upi_currency_type, created_at
        FROM buffer_transactions
        WHERE user_id = ?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ fetchBufferedTransactions: prepare failed")
            return result
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (userId as NSString).utf8String, -1, nil)

        while sqlite3_step(stmt) == SQLITE_ROW {
            func text(_ col: Int32) -> String {
                guard let ptr = sqlite3_column_text(stmt, col) else { return "" }
                return String(cString: ptr)
            }
            func optText(_ col: Int32) -> String? {
                guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
                let value = String(cString: ptr)
                return value.isEmpty ? nil : value
            }

            guard let id = UUID(uuidString: text(0)) else { continue }

            let timestampText = text(3)
            let createdAtText = optText(14)
            let timestamp = databaseDate(from: timestampText)
                ?? createdAtText.flatMap { databaseDate(from: $0) }
                ?? .distantPast
            let createdAt = createdAtText.flatMap { databaseDate(from: $0) } ?? timestamp
            let categoryId = optText(7).flatMap { UUID(uuidString: $0) }
            let statusInt = sqlite3_column_type(stmt, 8) != SQLITE_NULL
                ? sqlite3_column_int(stmt, 8)
                : -1
            let upiTxnId = optText(11)
            let upiMerchant = optText(12)
            let upiCurrency = optText(13)

            let upiInfo: UPIInfo? = upiTxnId.map {
                UPIInfo(
                    upiTransactionId: $0,
                    merchantName: upiMerchant ?? "",
                    currencyType: upiCurrency ?? "INR"
                )
            }

            result.append(
                BufferedTransaction(
                    id: id,
                    name: text(1),
                    amount: sqlite3_column_double(stmt, 2),
                    timestamp: timestamp,
                    note: optText(10),
                    createdAt: createdAt,
                    source: transactionSource(from: text(4)),
                    type: text(5) == "income" ? .income : .expense,
                    sourceName: optText(6),
                    categoryId: categoryId,
                    status: statusInt == -1 ? nil : statusInt == 1,
                    expenseType: optText(9),
                    upiInfo: upiInfo
                )
            )
        }

        result.sort { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp > rhs.timestamp
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }

        if let limit {
            return Array(result.prefix(limit))
        }

        return result
    }

    func fetchBufferedTransaction(id: UUID) -> BufferedTransaction? {
        fetchBufferedTransactions().first { $0.id == id }
    }

    @discardableResult
    func insertBufferedExpenseTransaction(
        name: String,
        amount: Double,
        timestamp: Date = Date(),
        categoryId: UUID?,
        status: Bool = true,
        expenseType: String = "receipt",
        source: TransactionSource = .receipt,
        note: String? = nil
    ) -> UUID? {
        guard let userId = currentUserIdString else { return nil }

        let sql = """
        INSERT INTO buffer_transactions
            (id, user_id, name, amount, timestamp, note, created_at,
             source, type, source_name, category_id, status, expense_type,
             upi_transaction_id, upi_merchant_name, upi_currency_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'expense', NULL, ?, ?, ?, NULL, NULL, NULL);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ insertBufferedExpenseTransaction: prepare failed")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        let transactionId = UUID()
        let timestampString = databaseTimestampString(from: timestamp)
        let createdAtString = databaseTimestampString(from: Date())

        sqlite3_bind_text(stmt, 1, (transactionId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (userId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, amount)
        sqlite3_bind_text(stmt, 5, (timestampString as NSString).utf8String, -1, nil)
        if let note, !note.isEmpty {
            sqlite3_bind_text(stmt, 6, (note as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        sqlite3_bind_text(stmt, 7, (createdAtString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 8, (sourceString(from: source) as NSString).utf8String, -1, nil)
        if let categoryId {
            sqlite3_bind_text(stmt, 9, (categoryId.uuidString as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 9)
        }
        sqlite3_bind_int(stmt, 10, status ? 1 : 0)
        sqlite3_bind_text(stmt, 11, (expenseType as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            print("❌ insertBufferedExpenseTransaction failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }

        return transactionId
    }

    @discardableResult
    func insertBufferedIncomeTransaction(
        name: String,
        amount: Double,
        timestamp: Date = Date(),
        sourceName: String,
        source: TransactionSource = .manual,
        note: String? = nil
    ) -> UUID? {
        guard let userId = currentUserIdString else { return nil }

        let sql = """
        INSERT INTO buffer_transactions
            (id, user_id, name, amount, timestamp, note, created_at,
             source, type, source_name, category_id, status, expense_type,
             upi_transaction_id, upi_merchant_name, upi_currency_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'income', ?, NULL, NULL, NULL, NULL, NULL, NULL);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ insertBufferedIncomeTransaction: prepare failed")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        let transactionId = UUID()
        let timestampString = databaseTimestampString(from: timestamp)
        let createdAtString = databaseTimestampString(from: Date())

        sqlite3_bind_text(stmt, 1, (transactionId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (userId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, amount)
        sqlite3_bind_text(stmt, 5, (timestampString as NSString).utf8String, -1, nil)
        if let note, !note.isEmpty {
            sqlite3_bind_text(stmt, 6, (note as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        sqlite3_bind_text(stmt, 7, (createdAtString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 8, (sourceString(from: source) as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 9, (sourceName as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            print("❌ insertBufferedIncomeTransaction failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }

        return transactionId
    }

    @discardableResult
    func insertExpenseTransaction(
        name: String,
        amount: Double,
        timestamp: Date = Date(),
        categoryId: UUID,
        status: Bool = true,
        expenseType: String = "bill",
        source: TransactionSource = .manual,
        note: String? = nil
    ) -> UUID? {
        guard let userId = currentUserIdString else { return nil }

        let sql = """
        INSERT INTO transactions
            (id, user_id, name, amount, timestamp, note, created_at,
             source, type, source_name, category_id, status, expense_type,
             upi_transaction_id, upi_merchant_name, upi_currency_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'expense', NULL, ?, ?, ?, NULL, NULL, NULL);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ insertExpenseTransaction: prepare failed")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        let transactionId = UUID()
        let timestampString = databaseTimestampString(from: timestamp)
        let createdAtString = databaseTimestampString(from: Date())

        sqlite3_bind_text(stmt, 1, (transactionId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (userId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, amount)
        sqlite3_bind_text(stmt, 5, (timestampString as NSString).utf8String, -1, nil)
        if let note, !note.isEmpty {
            sqlite3_bind_text(stmt, 6, (note as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        sqlite3_bind_text(stmt, 7, (createdAtString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 8, (sourceString(from: source) as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 9, (categoryId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 10, status ? 1 : 0)
        sqlite3_bind_text(stmt, 11, (expenseType as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            print("❌ insertExpenseTransaction failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }

        if isCurrentMonth(timestamp) {
            addToMonthlyExpense(amount)
        }
        return transactionId
    }

    @discardableResult
    func insertIncomeTransaction(
        name: String,
        amount: Double,
        timestamp: Date = Date(),
        sourceName: String,
        source: TransactionSource = .manual,
        note: String? = nil
    ) -> UUID? {
        guard let userId = currentUserIdString else { return nil }

        let sql = """
        INSERT INTO transactions
            (id, user_id, name, amount, timestamp, note, created_at,
             source, type, source_name, category_id, status, expense_type,
             upi_transaction_id, upi_merchant_name, upi_currency_type)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'income', ?, NULL, NULL, NULL, NULL, NULL, NULL);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ insertIncomeTransaction: prepare failed")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        let transactionId = UUID()
        let timestampString = databaseTimestampString(from: timestamp)
        let createdAtString = databaseTimestampString(from: Date())

        sqlite3_bind_text(stmt, 1, (transactionId.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (userId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 4, amount)
        sqlite3_bind_text(stmt, 5, (timestampString as NSString).utf8String, -1, nil)
        if let note, !note.isEmpty {
            sqlite3_bind_text(stmt, 6, (note as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        sqlite3_bind_text(stmt, 7, (createdAtString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 8, (sourceString(from: source) as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 9, (sourceName as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            print("❌ insertIncomeTransaction failed: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }

        return transactionId
    }

    @discardableResult
    func discardBufferedTransaction(id: UUID) -> Bool {
        guard let userId = currentUserIdString else { return false }

        let query = "DELETE FROM buffer_transactions WHERE id = ? AND user_id = ?;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ discardBufferedTransaction: prepare failed")
            return false
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (userId as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            print("❌ discardBufferedTransaction failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        return sqlite3_changes(db) > 0
    }

    @discardableResult
    func confirmBufferedTransaction(id: UUID) -> Bool {
        guard let bufferedTransaction = fetchBufferedTransaction(id: id),
              let userId = currentUserIdString
        else { return false }

        let beginResult = sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
        guard beginResult == SQLITE_OK else {
            print("❌ confirmBufferedTransaction: begin failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        let insertSQL = """
        INSERT INTO transactions
            (id, user_id, name, amount, timestamp, note, created_at,
             source, type, source_name, category_id, status, expense_type,
             upi_transaction_id, upi_merchant_name, upi_currency_type)
        SELECT id, user_id, name, amount, timestamp, note, ?,
               source, type, source_name, category_id, status, expense_type,
               upi_transaction_id, upi_merchant_name, upi_currency_type
        FROM buffer_transactions
        WHERE id = ? AND user_id = ?;
        """

        var insertStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            print("❌ confirmBufferedTransaction: insert prepare failed")
            return false
        }

        let confirmedAt = databaseTimestampString(from: Date())
        sqlite3_bind_text(insertStmt, 1, (confirmedAt as NSString).utf8String, -1, nil)
        sqlite3_bind_text(insertStmt, 2, (id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(insertStmt, 3, (userId as NSString).utf8String, -1, nil)

        guard sqlite3_step(insertStmt) == SQLITE_DONE else {
            sqlite3_finalize(insertStmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            print("❌ confirmBufferedTransaction: insert failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_finalize(insertStmt)

        let deleteSQL = "DELETE FROM buffer_transactions WHERE id = ? AND user_id = ?;"
        var deleteStmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            print("❌ confirmBufferedTransaction: delete prepare failed")
            return false
        }

        sqlite3_bind_text(deleteStmt, 1, (id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(deleteStmt, 2, (userId as NSString).utf8String, -1, nil)

        guard sqlite3_step(deleteStmt) == SQLITE_DONE else {
            sqlite3_finalize(deleteStmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            print("❌ confirmBufferedTransaction: delete failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }
        sqlite3_finalize(deleteStmt)

        guard sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            print("❌ confirmBufferedTransaction: commit failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        if bufferedTransaction.type == .expense,
           isCurrentMonth(bufferedTransaction.timestamp) {
            addToMonthlyExpense(bufferedTransaction.amount)
        }

        return true
    }

    func removeBillPaymentTransaction(billId: UUID) {
        guard let userId = currentUserIdString else { return }

        let note = billPaymentTransactionNote(for: billId)
        execute(
            "DELETE FROM transactions WHERE user_id = ? AND note = ?;",
            args: [userId, note]
        )
    }

    @discardableResult
    func updateTransaction(
        id: UUID,
        amount: Double,
        timestamp: Date,
        categoryId: UUID? = nil,
        sourceName: String? = nil
    ) -> Bool {
        guard let userId = currentUserIdString,
              let existingTransaction = fetchTransactions().first(where: { $0.id == id })
        else { return false }

        let timestampString = databaseTimestampString(from: timestamp)
        let query: String
        let updatedName: String

        if existingTransaction.type == .expense {
            guard let categoryId else { return false }
            let categoryName = fetchCategories().first(where: { $0.id == categoryId })?.name
            updatedName = categoryName ?? existingTransaction.name
            query = """
            UPDATE transactions
            SET name = ?, amount = ?, timestamp = ?, category_id = ?, source_name = NULL
            WHERE id = ? AND user_id = ?;
            """

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
                print("❌ updateTransaction: prepare failed")
                return false
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (updatedName as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, amount)
            sqlite3_bind_text(stmt, 3, (timestampString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (categoryId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 6, (userId as NSString).utf8String, -1, nil)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                print("❌ updateTransaction failed: \(String(cString: sqlite3_errmsg(db)))")
                return false
            }
        } else {
            let resolvedSourceName = sourceName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            updatedName = (resolvedSourceName?.isEmpty == false ? resolvedSourceName : nil)
                ?? existingTransaction.sourceName
                ?? existingTransaction.name
            query = """
            UPDATE transactions
            SET name = ?, amount = ?, timestamp = ?, source_name = ?, category_id = NULL
            WHERE id = ? AND user_id = ?;
            """

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
                print("❌ updateTransaction: prepare failed")
                return false
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, (updatedName as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 2, amount)
            sqlite3_bind_text(stmt, 3, (timestampString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (updatedName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 6, (userId as NSString).utf8String, -1, nil)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                print("❌ updateTransaction failed: \(String(cString: sqlite3_errmsg(db)))")
                return false
            }
        }

        guard sqlite3_changes(db) > 0 else {
            return false
        }

        resetMonthlyExpense()
        return true
    }

    @discardableResult
    func deleteTransaction(id: UUID) -> Bool {
        guard let userId = currentUserIdString,
              let transaction = fetchTransactions().first(where: { $0.id == id })
        else { return false }

        let query = "DELETE FROM transactions WHERE id = ? AND user_id = ?;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            print("❌ deleteTransaction: prepare failed")
            return false
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (userId as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            print("❌ deleteTransaction failed: \(String(cString: sqlite3_errmsg(db)))")
            return false
        }

        guard sqlite3_changes(db) > 0 else {
            return false
        }

        if let billId = billId(fromBillPaymentNote: transaction.note) {
            updateBillPaymentStatus(id: billId, isPaid: false)
        }

        resetMonthlyExpense()
        return true
    }

    func billPaymentNote(for billId: UUID) -> String {
        billPaymentTransactionNote(for: billId)
    }

    private func sourceString(from source: TransactionSource) -> String {
        switch source {
        case .upi: return "upi"
        case .receipt: return "receipt"
        case .ecommerce: return "ecommerce"
        case .manual: return "manual"
        }
    }

    private func transactionSource(from source: String) -> TransactionSource {
        switch source {
        case "upi": return .upi
        case "receipt": return .receipt
        case "ecommerce": return .ecommerce
        default: return .manual
        }
    }
}
