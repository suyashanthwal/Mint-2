//
//  QRCodeScannerViewModel.swift
//  QrScanner
//
//  Created on 2/12/26.
//

import Foundation
import Combine

final class QRCodeScannerViewModel: ObservableObject {
    
    
    @Published private(set) var scannedData: UPIQRCodeData?
    
    @Published private(set) var isScanning: Bool = false
    
    /// Error message to display to the user (nil if no error)
    @Published private(set) var errorMessage: String?
    
    
    private var lastScannedCode: String?
    private let scanCooldownInterval: TimeInterval = 2.0 // Prevent duplicate scans
    
    
    /// Starts the scanning session
    func startScanning() {
        isScanning = true
        scannedData = nil
        errorMessage = nil
        lastScannedCode = nil
    }
    
    /// Stops the scanning session
    func stopScanning() {
        isScanning = false
    }
    
    /// Resets all scanner state
    func resetScanner() {
        scannedData = nil
        errorMessage = nil
        lastScannedCode = nil
        isScanning = false
    }
    
    /// Parses a UPI QR code string and extracts payment information
    /// - Parameter qrString: The raw QR code string to parse
    /// - Returns: UPIQRCodeData if parsing succeeds, nil otherwise
    @discardableResult
    func parseUPIQRCode(_ qrString: String) -> UPIQRCodeData? {
        // Prevent duplicate processing of the same code
        if lastScannedCode == qrString {
            return nil
        }
        
        // Validate UPI format
        guard qrString.lowercased().hasPrefix("upi://pay") else {
            setError("Invalid QR code format. Please scan a valid UPI payment QR code.")
            return nil
        }
        
        // Parse URL components
        guard let url = URL(string: qrString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            setError("Unable to parse QR code data. Please try again.")
            return nil
        }
        
        // Extract parameters
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
        
        // Validate required fields
        guard let validPayeeID = payeeID, !validPayeeID.isEmpty else {
            setError("Invalid QR code: Missing payee information.")
            return nil
        }
        
        // Validate UPI ID format (basic check)
        guard isValidUPIID(validPayeeID) else {
            setError("Invalid UPI ID format.")
            return nil
        }
        
        // Create UPI data model
        let upiData = UPIQRCodeData(
            payeeID: validPayeeID,
            payeeName: payeeName,
            amount: amount,
            currency: currency,
            transactionNote: transactionNote
        )
        
        // Update state
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
    
    /// Validates UPI ID format (basic validation)
    /// - Parameter upiID: The UPI ID to validate
    /// - Returns: true if format appears valid, false otherwise
    private func isValidUPIID(_ upiID: String) -> Bool {
        let upiPattern = "^[a-zA-Z0-9._-]+@[a-zA-Z0-9]+$"
        let upiPredicate = NSPredicate(format: "SELF MATCHES %@", upiPattern)
        return upiPredicate.evaluate(with: upiID)
    }
}
