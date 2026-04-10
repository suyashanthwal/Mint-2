//
//  AzureReceiptService.swift
//  QrAndReceiptReading
//
//  Talks to Azure Document Intelligence (prebuilt-receipt model).
// pure URLSession over HTTPS.


import UIKit

//AzureReceiptService

final class AzureReceiptService {

    static let shared = AzureReceiptService()
    private init() {}

    // ── Azure config ─────────────────────────────────────────────────────────

    /// Read once at first use so the file is parsed only once.
    private lazy var secrets: [String: Any] = {
        guard let url  = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any]
        else {
            assertionFailure("Secrets.plist missing — see AzureReceiptService header comment.")
            return [:]
        }
        return dict
    }()

    private let apiVersion = "2024-11-30"
    private let modelID = "prebuilt-receipt"
    private let localeHint = "en-IN"

    private var endpoint: String { secrets["AzureEndpoint"] as? String ?? "" }
    private var apiKey:   String { secrets["AzureKey"]      as? String ?? "" }
    private var normalizedEndpoint: String {
        endpoint
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    private var normalizedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var isConfigured: Bool {
        configurationIssue == nil
    }
    var configurationIssue: String? {
        var missingKeys: [String] = []

        if normalizedEndpoint.isEmpty {
            missingKeys.append("AzureEndpoint")
        }
        if normalizedAPIKey.isEmpty {
            missingKeys.append("AzureKey")
        }

        guard !missingKeys.isEmpty else { return nil }
        return "Missing \(missingKeys.joined(separator: " and ")) in Secrets.plist"
    }

    /// Azure Document Intelligence REST path for the prebuilt receipt model.
    private var analyzeURL: String {
        "\(normalizedEndpoint)/documentintelligence/documentModels/\(modelID):analyze?_overload=analyzeDocument&api-version=\(apiVersion)&locale=\(localeHint)"
    }

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        return URLSession(configuration: configuration)
    }()

    //Polling

    private let maxPollAttempts = 20
    private let defaultPollInterval: TimeInterval = 2

    //Public API

    ///Sends image to Azure and returns a populated ReceiptScanData
    //Calls completion on the   main thread
    func analyze(image: UIImage,
                 completion: @escaping (Result<ReceiptScanData, AzureReceiptError>) -> Void) {
        guard let configurationIssue else {
            print("[AzureReceiptService] Starting Azure receipt analysis with API \(apiVersion).")
            print("[AzureReceiptService] Endpoint: \(normalizedEndpoint)")

            // 1:Compress image to JPEG
            guard let jpeg = image.jpegData(compressionQuality: 0.75) else {
                return complete(completion, .failure(.imageConversionFailed))
            }

            // 2:POST to Azure
            submitImage(jpeg) { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let e):
                    self.complete(completion, .failure(e))
                case .success(let operationURL):
                    print("[AzureReceiptService] Azure accepted request. Polling result at \(operationURL.absoluteString)")
                    // 3 ── Poll until Azure finishes, then parse
                    self.pollResult(operationURL: operationURL,
                                    attempt: 0,
                                    completion: completion)
                }
            }
            return
        }

        print("[AzureReceiptService] Azure configuration invalid: \(configurationIssue)")
        return complete(
            completion,
            .failure(.invalidConfiguration(configurationIssue))
        )
    }

    // ── Step 1: Submit ────────────────────────────────────────────────────────

    private func submitImage(_ jpeg: Data,
                             completion: @escaping (Result<URL, AzureReceiptError>) -> Void) {
        guard let url = URL(string: analyzeURL) else {
            return completion(.failure(.invalidConfiguration("Bad endpoint URL")))
        }

        let payload = ["base64Source": jpeg.base64EncodedString()]
        guard let requestBody = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return completion(.failure(.unexpectedResponse("Could not encode Azure request body")))
        }

        var request            = URLRequest(url: url)
        request.httpMethod     = "POST"
        request.setValue(normalizedAPIKey,  forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody       = requestBody

        session.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                return completion(.failure(.networkError(error)))
            }
            guard let http = response as? HTTPURLResponse else {
                return completion(.failure(.unexpectedResponse("No HTTP response")))
            }
            // Azure returns 202 Accepted + Operation-Location header on success
            guard http.statusCode == 202,
                  let locationString = http.value(forHTTPHeaderField: "Operation-Location"),
                  let locationURL    = URL(string: locationString)
            else {
                let details = self?.azureErrorMessage(from: data) ?? "No error body returned"
                let msg = "HTTP \(http.statusCode) — \(details)"
                return completion(.failure(.unexpectedResponse(msg)))
            }
            completion(.success(locationURL))
        }.resume()
    }

    // ── Step 2: Poll ─────────────────────────────────────────────────────────

    private func pollResult(operationURL: URL,
                            attempt: Int,
                            completion: @escaping (Result<ReceiptScanData, AzureReceiptError>) -> Void) {
        guard attempt < maxPollAttempts else {
            return complete(completion, .failure(.timeout))
        }

        var request = URLRequest(url: operationURL)
        request.setValue(normalizedAPIKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                return self.complete(completion, .failure(.networkError(error)))
            }
            guard let data else {
                return self.complete(completion, .failure(.unexpectedResponse("Empty poll response")))
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let status = json?["status"] as? String ?? "unknown"

                switch status {
                case "succeeded":
                    // 3 : Parse the JSON into ReceiptScanData
                    let scanData = AzureReceiptBridge.convert(json: json)
                    self.logAzureResult(json: json, scanData: scanData)
                    self.complete(completion, .success(scanData))

                case "failed":
                    let msg = (json?["error"] as? [String: Any])?["message"] as? String
                              ?? "Azure analysis failed"
                    self.complete(completion, .failure(.analysisError(msg)))

                default:
                    let retryAfter = self.retryInterval(from: response)
                    print("[AzureReceiptService] Azure status=\(status). Retrying in \(retryAfter)s.")
                    DispatchQueue.global().asyncAfter(deadline: .now() + retryAfter) {
                        self.pollResult(operationURL: operationURL,
                                        attempt: attempt + 1,
                                        completion: completion)
                    }
                }
            } catch {
                self.complete(completion, .failure(.jsonParsingFailed(error.localizedDescription)))
            }
        }.resume()
    }

    // ── Helper: always deliver on main thread ────────────────────────────────

    private func complete<T>(_ completion: @escaping (Result<T, AzureReceiptError>) -> Void,
                             _ result: Result<T, AzureReceiptError>) {
        DispatchQueue.main.async { completion(result) }
    }

    private func logAzureResult(json: [String: Any]?, scanData: ReceiptScanData) {
#if DEBUG
        print("[AzureReceiptService] Azure receipt analysis succeeded.")

        if let json,
           let prettyJSON = prettyPrintedJSONString(from: json) {
            print("[AzureReceiptService] Raw Azure JSON:\n\(prettyJSON)")
        } else {
            print("[AzureReceiptService] Raw Azure JSON: <unavailable>")
        }

        print("[AzureReceiptService] Parsed ReceiptScanData:\n\(formattedScanData(scanData))")
#endif
    }

    private func prettyPrintedJSONString(from json: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(json),
              let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private func retryInterval(from response: URLResponse?) -> TimeInterval {
        guard let http = response as? HTTPURLResponse,
              let retryAfterValue = http.value(forHTTPHeaderField: "Retry-After"),
              let retryAfter = TimeInterval(retryAfterValue) else {
            return defaultPollInterval
        }
        return retryAfter
    }

    private func azureErrorMessage(from data: Data?) -> String? {
        guard let data else { return nil }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }

        guard let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !body.isEmpty else {
            return nil
        }

        return body
    }

    private func formattedScanData(_ scanData: ReceiptScanData) -> String {
        let itemLines = scanData.lineItems.enumerated().map { index, item in
            let quantity = formattedOptionalNumber(item.quantity)
            let unitPrice = formattedOptionalNumber(item.unitPrice)
            let totalPrice = formattedOptionalNumber(item.totalPrice)
            return "  [\(index)] name=\(item.name), qty=\(quantity), unitPrice=\(unitPrice), totalPrice=\(totalPrice)"
        }

        let taxLines = scanData.taxLines.enumerated().map { index, item in
            "  [\(index)] \(item.name)=\(formattedOptionalNumber(item.amount))"
        }

        let lines = [
            "merchantName: \(scanData.merchantName ?? "nil")",
            "invoiceNumber: \(scanData.invoiceNumber ?? "nil")",
            "date: \(formattedOptionalDate(scanData.date))",
            "time: \(scanData.time ?? "nil")",
            "subtotal: \(formattedOptionalNumber(scanData.subtotal))",
            "totalTax: \(formattedOptionalNumber(scanData.totalTax))",
            "grandTotal: \(formattedOptionalNumber(scanData.grandTotal))",
            "amountPaid: \(formattedOptionalNumber(scanData.amountPaid))",
            "paymentMethod: \(scanData.paymentMethod ?? "nil")",
            "currency: \(scanData.currency)",
            "taxLines:",
            taxLines.isEmpty ? "  <none>" : taxLines.joined(separator: "\n"),
            "lineItems:",
            itemLines.isEmpty ? "  <none>" : itemLines.joined(separator: "\n")
        ]

        return lines.joined(separator: "\n")
    }

    private func formattedOptionalNumber(_ value: Double?) -> String {
        guard let value else { return "nil" }
        return String(value)
    }

    private func formattedOptionalDate(_ value: Date?) -> String {
        guard let value else { return "nil" }
        return value.description
    }
}

// AzureReceiptError

enum AzureReceiptError: Error, LocalizedError {
    case imageConversionFailed
    case invalidConfiguration(String)
    case networkError(Error)
    case unexpectedResponse(String)
    case timeout
    case analysisError(String)
    case jsonParsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:        return "Could not compress receipt image."
        case .invalidConfiguration(let m):  return "Azure config error: \(m)"
        case .networkError(let e):          return "Network error: \(e.localizedDescription)"
        case .unexpectedResponse(let m):    return "Unexpected response: \(m)"
        case .timeout:                      return "Azure took too long — please try again."
        case .analysisError(let m):         return "Azure error: \(m)"
        case .jsonParsingFailed(let m):     return "Could not read Azure response: \(m)"
        }
    }
}

// MARK: - AzureReceiptBridge (JSON → ReceiptScanData)

/// Converts the raw Azure Document Intelligence JSON into your existing ReceiptScanData model.
/// Field access is aligned to the v4.0 response shape, with text fallbacks where Azure omits a structured field.
enum AzureReceiptBridge {

    static func convert(json: [String: Any]?) -> ReceiptScanData {
        var data = ReceiptScanData()

        // Navigate: analyzeResult → documents[0] → fields
        guard let analyzeResult = json?["analyzeResult"] as? [String: Any],
              let documents     = analyzeResult["documents"] as? [[String: Any]],
              let fields        = documents.first?["fields"] as? [String: Any]
        else { return data }

        let documentText = analyzeResult["content"] as? String ?? ""
        data.rawOCRText = documentText

        // ── Scalar fields ──────────────────────────────────────────────────

        data.merchantName   = stringField(fields, "MerchantName")
        data.invoiceNumber  = stringField(fields, "TransactionId")
                            ?? stringField(fields, "InvoiceId")
                            ?? invoiceNumber(from: documentText)
        data.paymentMethod  = stringField(fields, "PaymentMethod")
                            ?? paymentMethod(from: documentText)
        data.currency       = stringField(fields, "Currency")
                            ?? currencyCodeField(fields, "Total")
                            ?? "INR"

        data.taxLines       = taxLines(from: fields)
        data.cgst           = taxAmount(in: data.taxLines, matchingAny: ["cgst"])
        data.sgst           = taxAmount(in: data.taxLines, matchingAny: ["sgst"])
        data.igst           = taxAmount(in: data.taxLines, matchingAny: ["igst"])

        data.subtotal       = currencyField(fields, "Subtotal")
        data.totalTax       = currencyField(fields, "TotalTax")
                            ?? (!data.taxLines.isEmpty ? data.taxLines.reduce(0) { $0 + $1.amount } : nil)
                            ?? summedTaxDetails(fields)
        data.grandTotal     = currencyField(fields, "Total")
        data.amountPaid     = currencyField(fields, "AmountDue")
                            ?? currencyField(fields, "Total")

        // ── Date & Time ───────────────────────────────────────────────────

        data.date = dateField(fields, "TransactionDate")
        data.time = timeField(fields, "TransactionTime")

        // ── Line items ────────────────────────────────────────────────────

        if let itemsField = fields["Items"] as? [String: Any],
           let itemsArray = itemsField["valueArray"] as? [[String: Any]] {

            data.lineItems = itemsArray.compactMap { itemWrapper -> ReceiptLineItem? in
                guard let itemFields = itemWrapper["valueObject"] as? [String: Any] else {
                    return nil
                }

                let description = (stringField(itemFields, "Description") ?? "Unknown Item")
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let quantity    = doubleField(itemFields, "Quantity")
                let unitPrice   = currencyField(itemFields, "UnitPrice")
                                ?? currencyField(itemFields, "Price")
                let totalPrice  = currencyField(itemFields, "TotalPrice")

                return ReceiptLineItem(
                    name:       description,
                    quantity:   quantity,
                    unitPrice:  unitPrice,
                    totalPrice: totalPrice
                )
            }
        }

        return data
    }

    // ── Field extractors ───────────────────────────────────────────────────

    /// Extracts a string from { "valueString": "...", "content": "..." }
    private static func stringField(_ fields: [String: Any], _ key: String) -> String? {
        guard let field = fields[key] as? [String: Any] else { return nil }
        return (field["valueString"] as? String)
            ?? (field["content"]     as? String)
    }

    private static func dateField(_ fields: [String: Any], _ key: String) -> Date? {
        guard let field = fields[key] as? [String: Any] else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        if let valueDate = field["valueDate"] as? String,
           let date = formatter.date(from: valueDate) {
            return date
        }

        if let content = field["content"] as? String,
           let date = formatter.date(from: content) {
            return date
        }

        return nil
    }

    private static func timeField(_ fields: [String: Any], _ key: String) -> String? {
        guard let field = fields[key] as? [String: Any] else { return nil }
        return (field["valueTime"] as? String)
            ?? (field["content"] as? String)
    }

    /// Extracts a Double from { "valueCurrency": { "amount": 99.5 } }
    private static func currencyField(_ fields: [String: Any], _ key: String) -> Double? {
        guard let field    = fields[key]            as? [String: Any],
              let currency = field["valueCurrency"]  as? [String: Any],
              let amount   = currency["amount"]      as? Double
        else { return nil }
        return amount
    }

    /// Extracts a Double from { "valueNumber": 2.0 }
    private static func doubleField(_ fields: [String: Any], _ key: String) -> Double? {
        guard let field = fields[key] as? [String: Any] else { return nil }
        return field["valueNumber"] as? Double
    }

    private static func currencyCodeField(_ fields: [String: Any], _ key: String) -> String? {
        guard let field = fields[key] as? [String: Any],
              let currency = field["valueCurrency"] as? [String: Any] else { return nil }
        return currency["currencyCode"] as? String
    }

    private static func taxLines(from fields: [String: Any]) -> [ReceiptTaxLine] {
        guard let taxField = fields["TaxDetails"] as? [String: Any],
              let taxArray = taxField["valueArray"] as? [[String: Any]] else {
            return []
        }

        return taxArray.compactMap { entry in
            let taxObject = entry["valueObject"] as? [String: Any]
            let name = (taxObject.flatMap { stringField($0, "Description") }
                ?? amountLabel(from: entry["content"] as? String ?? ""))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let amount = taxObject.flatMap { currencyField($0, "Amount") }
                ?? amountFromText(entry["content"] as? String ?? "")

            guard !name.isEmpty, let amount else { return nil }
            return ReceiptTaxLine(name: name, amount: amount)
        }
    }

    private static func taxAmount(in taxLines: [ReceiptTaxLine], matchingAny keywords: [String]) -> Double? {
        taxLines.first { taxLine in
            let lowercasedName = taxLine.name.lowercased()
            return keywords.contains { lowercasedName.contains($0) }
        }?.amount
    }

    private static func summedTaxDetails(_ fields: [String: Any]) -> Double? {
        guard let taxField = fields["TaxDetails"] as? [String: Any],
              let taxArray = taxField["valueArray"] as? [[String: Any]] else {
            return nil
        }

        let values = taxArray.compactMap { entry -> Double? in
            guard let taxObject = entry["valueObject"] as? [String: Any] else { return nil }
            return currencyField(taxObject, "Amount")
        }

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private static func amountLabel(from text: String) -> String {
        let parts = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.count > 1 {
            return parts.dropLast().joined(separator: " ")
        }

        return parts.first ?? ""
    }

    private static func amountFromText(_ text: String) -> Double? {
        let pattern = #"([0-9][0-9,]*\.?[0-9]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches.reversed() {
            guard let capturedRange = Range(match.range(at: 1), in: text) else { continue }
            let candidate = text[capturedRange]
                .replacingOccurrences(of: ",", with: "")
            if let value = Double(candidate) {
                return value
            }
        }

        return nil
    }

    private static func invoiceNumber(from text: String) -> String? {
        firstMatch(
            pattern: #"(?im)invoice\s*(?:number|no\.?|#)?\s*:\s*([A-Z0-9\-/]+)"#,
            in: text
        )
    }

    private static func paymentMethod(from text: String) -> String? {
        let lower = text.lowercased()
        let candidates: [(keyword: String, label: String)] = [
            ("phonepe", "PhonePe"),
            ("gpay", "Google Pay"),
            ("google pay", "Google Pay"),
            ("paytm", "Paytm"),
            ("upi", "UPI"),
            ("credit card", "Credit Card"),
            ("debit card", "Debit Card"),
            ("card", "Card"),
            ("cash", "Cash")
        ]

        return candidates.first { lower.contains($0.keyword) }?.label
    }

    private static func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}
