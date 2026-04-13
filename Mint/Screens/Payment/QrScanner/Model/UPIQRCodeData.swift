
import Foundation

struct UPIQRCodeData {
    let payeeID: String
    
    let payeeName: String?
    
    let amount: Double
    
    let currency: String
    
    let transactionNote: String?
    
    init(payeeID: String, payeeName: String? = nil, amount: Double = 0.0, currency: String = "INR", transactionNote: String? = nil) {
        self.payeeID = payeeID
        self.payeeName = payeeName
        self.amount = amount
        self.currency = currency
        self.transactionNote = transactionNote
    }
}

extension UPIQRCodeData: CustomStringConvertible {
    var description: String {
        return """
        UPI Payment Details:
        - Payee: \(payeeName ?? "Unknown")
        - UPI ID: \(payeeID)
        - Amount: \(currency) \(amount)
        \(transactionNote != nil ? "- Note: \(transactionNote!)" : "")
        """
    }
}
