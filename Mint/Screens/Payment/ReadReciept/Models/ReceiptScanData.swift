import Foundation

// MARK: - ReceiptScanData
// Produced by IndianReceiptParserService after parsing OCR text.
// All fields are optional because OCR is imperfect.

struct ReceiptScanData {
    var merchantName: String?
    var invoiceNumber: String?
    var date: Date?
    var time: String?
    var subtotal: Double?
    var cgst: Double?
    var sgst: Double?
    var igst: Double?
    var totalTax: Double?
    var grandTotal: Double?
    var amountPaid: Double?
    var paymentMethod: String?
    var currency: String = "INR"
    var taxLines: [ReceiptTaxLine]
    var lineItems: [ReceiptLineItem]
    var rawOCRText: String

    init() {
        self.taxLines = []
        self.lineItems = []
        self.rawOCRText = ""
    }
    
}

// ReceiptLineItem

struct ReceiptLineItem {
    var name: String
    var quantity: Double?
    var unitPrice: Double?
    var totalPrice: Double?
}

struct ReceiptTaxLine {
    var name: String
    var amount: Double
}

// ReceiptScanResult

enum ReceiptScanResult {
    case success(ReceiptScanData)
    case failure(ReceiptOCRError)
}

// ReceiptOCRError

enum ReceiptOCRError: Error, LocalizedError {
    case noImageProvided
    case ocrFailed(String)
    case noTextFound
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .noImageProvided:
            return "No image was selected."
        case .ocrFailed(let m):
            return "OCR failed: \(m)"
        case .noTextFound:
            return "No text could be read from the image."
        case .parsingFailed:
            return "Could not parse the receipt."
        }
    }
}
