import Foundation

enum InsightTextSanitizer {
    private static let placeholderKeys: Set<String> = [
        "home",
        "home_digest",
        "homedigest",
        "summary",
        "categorybreakdown",
        "category_highlight",
        "categoryhighlight",
        "subscriptionsbills",
        "subs_and_bills",
        "subsandbills",
        "goal_insight",
        "goalinsight"
    ]

    private static let blockedPrefixes: [String] = [
        "could not",
        "no insight",
        "n/a",
        "none",
        "null"
    ]

    private static let blockedPromptFragments: [String] = [
        "budget pace",
        "concrete next action",
        "behavioral pattern",
        "small rule to try",
        "bill prep",
        "urgent bill prep",
        "subscription audit opportunity"
    ]

    private static let lowValueMarkers: [String] = [
        "spend is ",
        "spending is ",
        "spending stands at ",
        "peaked on day ",
        "leads spending at ",
        "upcoming unpaid bills currently add up to ",
        "active subscriptions total ",
        "your total expense",
        "you have spent",
        "you spent a total",
        "total spending for",
        "goal is % complete",
        "you have saved",
        "subscriptions cost",
        "bills total"
    ]

    static func sanitize(_ text: String?) -> String {
        let cleanedText = text?
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ") ?? ""

        let comparisonText = normalizedComparisonText(from: cleanedText)
        guard !cleanedText.isEmpty else { return "" }

        if blockedPrefixes.contains(where: { comparisonText.hasPrefix(normalizedComparisonText(from: $0)) }) {
            return ""
        }

        if placeholderKeys.contains(comparisonText) {
            return ""
        }

        if blockedPromptFragments.contains(where: { comparisonText.contains(normalizedComparisonText(from: $0)) }) {
            return ""
        }

        if lowValueMarkers.contains(where: { comparisonText.contains(normalizedComparisonText(from: $0)) }) {
            return ""
        }

        return cleanedText
    }

    private static func normalizedComparisonText(from text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
