
import Foundation
import Combine

final class QRCodeScannerViewModel: ObservableObject {
    
    
    @Published private(set) var scannedData: UPIQRCodeData?
    
    @Published private(set) var isScanning: Bool = false
    
    @Published private(set) var errorMessage: String?
    
    
    private var lastScannedCode: String?
    private let scanCooldownInterval: TimeInterval = 2.0
    
    
    func startScanning() {
        isScanning = true
        scannedData = nil
        errorMessage = nil
        lastScannedCode = nil
    }
    
    func stopScanning() {
        isScanning = false
    }
    
    func resetScanner() {
        scannedData = nil
        errorMessage = nil
        lastScannedCode = nil
        isScanning = false
    }
    
    @discardableResult
    func parseUPIQRCode(_ qrString: String) -> UPIQRCodeData? {
        if lastScannedCode == qrString {
            return nil
        }
        
        guard qrString.lowercased().hasPrefix("upi://pay") else {
            setError("Invalid QR code format. Please scan a valid UPI payment QR code.")
            return nil
        }
        
        guard let url = URL(string: qrString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            setError("Unable to parse QR code data. Please try again.")
            return nil
        }
        
        var payeeID: String?
        var payeeName: String?
        var amount: Double = 0.0
        var currency: String = "INR"
        var transactionNote: String?
        
        for item in queryItems {
            guard let value = item.value, !value.isEmpty else { continue }
            
            switch item.name.lowercased() {
            case "pa":
                payeeID = value
            case "pn":
                payeeName = value.removingPercentEncoding
            case "am":
                amount = Double(value) ?? 0.0
            case "cu":
                currency = value.uppercased()
            case "tn":
                transactionNote = value.removingPercentEncoding
            default:
                break
            }
        }
        
        guard let validPayeeID = payeeID, !validPayeeID.isEmpty else {
            setError("Invalid QR code: Missing payee information.")
            return nil
        }
        
        guard isValidUPIID(validPayeeID) else {
            setError("Invalid UPI ID format.")
            return nil
        }
        
        let upiData = UPIQRCodeData(
            payeeID: validPayeeID,
            payeeName: payeeName,
            amount: amount,
            currency: currency,
            transactionNote: transactionNote
        )
        
        lastScannedCode = qrString
        scannedData = upiData
        errorMessage = nil
        stopScanning()
        
        return upiData
    }
    
    
    private func setError(_ message: String) {
        errorMessage = message
        scannedData = nil
    }
    
    private func isValidUPIID(_ upiID: String) -> Bool {
        let upiPattern = "^[a-zA-Z0-9._-]+@[a-zA-Z0-9]+$"
        let upiPredicate = NSPredicate(format: "SELF MATCHES %@", upiPattern)
        return upiPredicate.evaluate(with: upiID)
    }
}
