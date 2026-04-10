//
//  UPIQRCodeData.swift
//  QrScanner
//
//  Created on 2/12/26.
//

import Foundation

/// Model representing UPI QR Code payment data
struct UPIQRCodeData {
    /// Payee's UPI ID (e.g., "payee@upi")
    let payeeID: String
    
    /// Payee's display name (optional, URL-decoded)
    let payeeName: String?
    
    /// Payment amount (defaults to 0.0 if not specified)
    let amount: Double
    
    /// Currency code (defaults to INR)
    let currency: String
    
    /// Transaction reference/note (optional)
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
