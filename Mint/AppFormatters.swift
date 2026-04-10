import Foundation

struct AppFormatters {

    static let inrCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static let shortBillDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static let monthOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    static let yearOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    static let hourOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter
    }()

    static let timeWithMeridiem: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static let shortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static func currency(_ value: Double) -> String {
        return inrCurrency.string(from: NSNumber(value: value)) ?? "₹0.00"
    }

    static func month(_ date: Date) -> String {
        monthOnly.string(from: date)
    }

    static func year(_ date: Date) -> String {
        yearOnly.string(from: date)
    }

    static func transactionDate(_ date: Date) -> String {
        monthDay.string(from: date)
    }

    static func transactionAmount(for transaction: Transaction) -> String {
        let signedAmount = transaction.type == .expense ? -transaction.amount : transaction.amount
        return currency(signedAmount)
    }
}
