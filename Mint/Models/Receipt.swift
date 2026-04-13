
import Foundation

struct Receipt: Identifiable, Codable {
    
    let id: UUID
    var merchantName: String
    var transactionIds: Set<UUID>
    var totalAmount: Double
    var date: Date
    var note: String?
    var createdAt: Date
    
    init(merchantName: String,
         transactionIds: Set<UUID>,
         totalAmount: Double,
         date: Date,
         note: String? = nil) {
        
        self.id = UUID()
        self.merchantName = merchantName
        self.transactionIds = transactionIds
        self.totalAmount = totalAmount
        self.date = date
        self.note = note
        self.createdAt = Date()
    }
}
