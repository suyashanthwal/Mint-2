
import Foundation

enum TimeRange: Int {
    case daily   = 0
    case weekly  = 1
    case monthly = 2
    case yearly  = 3
}

enum TransactionSource: Codable {
    case upi
    case manual
    case receipt
    case ecommerce
}

enum TransactionType: Codable {
    case income
    case expense
}

enum PaymentSource: String, Codable, CaseIterable {
    case upi
    case ecommerce
    case cash
}

struct UPIInfo: Codable {
    
    var upiTransactionId: String
    var merchantName: String
    var currencyType: String
    
    init(upiTransactionId: String,
         merchantName: String,
         currencyType: String) {
        
        self.upiTransactionId = upiTransactionId
        self.merchantName = merchantName
        self.currencyType = currencyType
    }
}

struct Transaction: Identifiable, Codable {
    
    let id: UUID
    var name: String
    var amount: Double
    var timestamp: Date
    var note: String?
    var createdAt: Date
    var source: TransactionSource
    var type: TransactionType
    var sourceName: String?
    var categoryId: UUID?
    var status: Bool?
    var expenseType: String?
    var upiInfo: UPIInfo?
    
    
    init(name: String,
         amount: Double,
         timestamp: Date,
         id: UUID = UUID(),
         createdAt: Date = Date(),
         sourceName: String,
         note: String? = nil) {
        
        self.id = id
        self.name = name
        self.amount = amount
        self.timestamp = timestamp
        self.source = .manual
        self.type = .income
        self.note = note
        self.createdAt = createdAt
        self.sourceName = sourceName
        self.categoryId = nil
        self.status = nil
        self.expenseType = nil
        self.upiInfo = nil
    }

    
    init(name: String,
         amount: Double,
         timestamp: Date,
         id: UUID = UUID(),
         createdAt: Date = Date(),
         categoryId: UUID,
         status: Bool,
         expenseType: String,
         source: TransactionSource,
         note: String? = nil,
         upiInfo: UPIInfo? = nil) {
        
        self.id = id
        self.name = name
        self.amount = amount
        self.timestamp = timestamp
        self.source = source
        self.type = .expense
        self.note = note
        self.createdAt = createdAt
        self.categoryId = categoryId
        self.status = status
        self.expenseType = expenseType
        self.upiInfo = upiInfo
        self.sourceName = nil
    }
}

struct BufferedTransaction: Identifiable, Codable {

    let id: UUID
    var name: String
    var amount: Double
    var timestamp: Date
    var note: String?
    var createdAt: Date
    var source: TransactionSource
    var type: TransactionType
    var sourceName: String?
    var categoryId: UUID?
    var status: Bool?
    var expenseType: String?
    var upiInfo: UPIInfo?

    var asTransaction: Transaction {
        switch type {
        case .income:
            return Transaction(
                name: name,
                amount: amount,
                timestamp: timestamp,
                id: id,
                createdAt: createdAt,
                sourceName: sourceName ?? "",
                note: note
            )
        case .expense:
            return Transaction(
                name: name,
                amount: amount,
                timestamp: timestamp,
                id: id,
                createdAt: createdAt,
                categoryId: categoryId ?? UUID(),
                status: status ?? true,
                expenseType: expenseType ?? "",
                source: source,
                note: note,
                upiInfo: upiInfo
            )
        }
    }
}
