import Foundation

final class IndianReceiptParserService {
    
    static let shared = IndianReceiptParserService()
    private init() {}

    
    func parse(rawText: String) -> ReceiptScanData {
        var data = ReceiptScanData()
        data.rawOCRText = rawText

        let cleaned = normalize(rawText)
        let lines = cleaned.components(separatedBy: "\n")
                           .map { $0.trimmingCharacters(in: .whitespaces) }
                           .filter { !$0.isEmpty }

        data.merchantName = extractMerchantName(lines: lines)
        data.invoiceNumber = extractInvoiceNumber(text: cleaned)
        data.date = extractDate(text: cleaned)
        data.time = extractTime(text: cleaned)
        data.subtotal = extractAmount(for: subtotalPatterns, in: cleaned)
        data.cgst = extractAmount(for: cgstPatterns, in: cleaned)
        data.sgst = extractAmount(for: sgstPatterns, in: cleaned)
        data.igst = extractAmount(for: igstPatterns, in: cleaned)
        data.grandTotal = extractAmount(for: grandTotalPatterns, in: cleaned)
        data.amountPaid = extractAmount(for: amountPaidPatterns, in: cleaned)
        data.paymentMethod = extractPaymentMethod(text: cleaned)
        data.lineItems = extractLineItems(lines: lines)

        if data.totalTax == nil {
            let t = (data.cgst ?? 0) + (data.sgst ?? 0) + (data.igst ?? 0)
            if t > 0 { data.totalTax = t }
        }

        data.taxLines = [
            data.cgst.map { ReceiptTaxLine(name: "CGST", amount: $0) },
            data.sgst.map { ReceiptTaxLine(name: "SGST", amount: $0) },
            data.igst.map { ReceiptTaxLine(name: "IGST", amount: $0) }
        ].compactMap { $0 }

        if data.grandTotal == nil { data.grandTotal = data.amountPaid }

        return data
    }

    
    private func normalize(_ text: String) -> String {
        var s = text

        s = s.replacingOccurrences(of: #"[¥?@]\s*(?=\d)"#,
                                   with: "₹", options: .regularExpression)
        s = s.replacingOccurrences(of: "l", with: "1")
        s = s.replacingOccurrences(of: #"(?<=\d)O(?=\d)"#,
                                   with: "0", options: .regularExpression)
        s = s.replacingOccurrences(of: "Tota1", with: "Total", options: .caseInsensitive)

        s = s.replacingOccurrences(of: "6ST", with: "GST", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "Gst", with: "GST")
        s = s.replacingOccurrences(of: "C6ST", with: "CGST", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "S6ST", with: "SGST", options: .caseInsensitive)

        s = s.replacingOccurrences(of: "UPl", with: "UPI", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "UPi", with: "UPI", options: .caseInsensitive)

        s = s.replacingOccurrences(of: "lnvoice", with: "Invoice", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "lNVOICE", with: "INVOICE", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "Bi11", with: "Bill", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "Subt0tal", with: "Subtotal", options: .caseInsensitive)
        s = s.replacingOccurrences(of: "Arnount", with: "Amount", options: .caseInsensitive)

        s = s.replacingOccurrences(of: #"[ \t]{2,}"#,
                                   with: " ", options: .regularExpression)

        return s
    }

    
    private func extractMerchantName(lines: [String]) -> String? {
        let skipPatterns = [
            #"^\d"#,
            #"(?i)(invoice|receipt|bill|gst|tax|total|date|time|tel|ph|fax|gstin|www|http|@)"#,
            #"[:\-=]"#,
        ]
        for line in lines.prefix(6) {
            let isSkip = skipPatterns.contains { line.range(of: $0, options: .regularExpression) != nil }
            if !isSkip && line.count > 3 {
                return line
                    .trimmingCharacters(in: .punctuationCharacters)
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    
    private func extractInvoiceNumber(text: String) -> String? {
        let patterns = [
            #"(?i)(?:invoice\s*(?:no|num|number)?|bill\s*(?:no|num|number)?|receipt\s*(?:no|num)?|order\s*(?:no|id)?)\s*[:\-#]?\s*([A-Z0-9\-/]{3,20})"#,
        ]
        for pattern in patterns {
            if let match = firstCapture(pattern: pattern, in: text) {
                return match
            }
        }
        return nil
    }

    
    private let dateFormats = [
        "dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy",
        "dd/MM/yy", "dd-MM-yy",
        "d MMM yyyy", "d MMMM yyyy",
        "yyyy-MM-dd",
        "dd MMM, yyyy",
    ]

    private func extractDate(text: String) -> Date? {
        let datePatterns = [
            #"(?i)(?:date|dt|dated?)\s*[:\-]?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})"#,
            #"(?i)(?:date|dt)\s*[:\-]?\s*(\d{1,2}\s+\w{3,}\s+\d{2,4})"#,
            #"(?<!\d)(\d{2}[\/\-\.]\d{2}[\/\-\.]\d{4})(?!\d)"#,
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        for pattern in datePatterns {
            if let raw = firstCapture(pattern: pattern, in: text) {
                let normalised = raw
                    .replacingOccurrences(of: "-", with: "/")
                    .replacingOccurrences(of: ".", with: "/")
                for fmt in dateFormats {
                    formatter.dateFormat = fmt
                    if let date = formatter.date(from: normalised) { return date }
                    if let date = formatter.date(from: raw) { return date }
                }
            }
        }
        return nil
    }

    
    private func extractTime(text: String) -> String? {
        let patterns = [
            #"(?i)time\s*[:\-]?\s*(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[AP]M)?)"#,
            #"(?<!\d)(\d{1,2}:\d{2}\s*[AP]M)(?!\d)"#,
        ]
        for p in patterns {
            if let t = firstCapture(pattern: p, in: text) { return t }
        }
        return nil
    }

    
    private let subtotalPatterns = [
        #"(?i)sub\s*total\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
        #"(?i)net\s*amount\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
        #"(?i)taxable\s*value\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
        #"(?i)basic\s*(?:amount|total)\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
    ]

    private let cgstPatterns = [
        #"(?i)cgst\s*(?:@\s*\d+%?)?\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
    ]

    private let sgstPatterns = [
        #"(?i)sgst\s*(?:@\s*\d+%?)?\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
    ]

    private let igstPatterns = [
        #"(?i)igst\s*(?:@\s*\d+%?)?\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
    ]

    private let grandTotalPatterns = [
        #"(?i)grand\s*total\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
        #"(?i)total\s*amount\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
        #"(?i)(?:^|\n)\s*total\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
        #"(?i)net\s*payable\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
        #"(?i)bill\s*amount\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
    ]

    private let amountPaidPatterns = [
        #"(?i)amount\s*paid\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
        #"(?i)paid\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
        #"(?i)(?:cash|card|upi)\s*(?:paid|received|tendered)?\s*[:\-]?\s*(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.?\d*)"#,
    ]

    private func extractAmount(for patterns: [String], in text: String) -> Double? {
        for pattern in patterns {
            if let raw = firstCapture(pattern: pattern, in: text) {
                let digits = raw.replacingOccurrences(of: ",", with: "")
                if let value = Double(digits), value > 0 { return value }
            }
        }
        return nil
    }

    
    private func extractPaymentMethod(text: String) -> String? {
        let methods: [(keyword: String, label: String)] = [
            ("phonepe", "PhonePe"),
            ("phone pe", "PhonePe"),
            ("googlepay", "Google Pay"),
            ("google pay", "Google Pay"),
            ("gpay", "Google Pay"),
            ("paytm", "Paytm"),
            ("bhim", "BHIM UPI"),
            ("amazonpay", "Amazon Pay"),
            ("amazon pay", "Amazon Pay"),
            ("upi", "UPI"),
            ("credit card", "Credit Card"),
            ("debit card", "Debit Card"),
            ("card", "Card"),
            ("cash", "Cash"),
            ("neft", "NEFT"),
            ("rtgs", "RTGS"),
            ("net banking", "Net Banking"),
        ]
        let lower = text.lowercased()
        for (keyword, label) in methods {
            if lower.contains(keyword) { return label }
        }
        return nil
    }

    
    private func extractLineItems(lines: [String]) -> [ReceiptLineItem] {
        var items: [ReceiptLineItem] = []

        let lineItemPattern = #"^(.+?)\s{2,}(?:(\d+(?:\.\d+)?)\s{1,})?(?:₹|Rs\.?\s*|INR\s*)?([\d,]+\.\d{2})\s*$"#
        let regex = try? NSRegularExpression(pattern: lineItemPattern)

        let skipWords = ["total", "tax", "gst", "cgst", "sgst", "igst",
                         "subtotal", "discount", "amount", "date", "invoice",
                         "thank", "www", "phone", "address", "gstin"]

        for line in lines {
            let lower = line.lowercased()
            if skipWords.contains(where: { lower.hasPrefix($0) }) { continue }
            guard let r = regex,
                  let m = r.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  m.numberOfRanges >= 4 else { continue }

            func capture(_ i: Int) -> String? {
                let range = m.range(at: i)
                guard range.location != NSNotFound,
                      let r = Range(range, in: line) else { return nil }
                return String(line[r]).trimmingCharacters(in: .whitespaces)
            }

            guard let name = capture(1), !name.isEmpty else { continue }
            let qty = capture(2).flatMap { Double($0.replacingOccurrences(of: ",", with: "")) }
            let price = capture(3).flatMap { Double($0.replacingOccurrences(of: ",", with: "")) }

            guard let total = price else { continue }
            let item = ReceiptLineItem(
                name: name,
                quantity: qty,
                unitPrice: (qty != nil && qty! > 0) ? total / qty! : nil,
                totalPrice: total
            )
            items.append(item)
        }

        return items
    }

    
    private func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        let range = match.range(at: 1)
        guard range.location != NSNotFound else { return nil }
        return ns.substring(with: range)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
