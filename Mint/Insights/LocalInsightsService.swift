import Foundation
import FoundationModels

@available(iOS 26.0, *)
@Generable(description: "Short financial insights for Mint app screens.")
private struct LocalInsightGeneration {
    let homeDigest: String
    let summary: String
    let categoryHighlight: String
    let subsAndBills: String
}

final class LocalInsightsService {
    static let shared = LocalInsightsService()

    private init() {}

    func generateHomeInsights(for envelope: HomeInsightsEnvelope) async -> HomeInsightsResponse {
        let payload = LocalInsightsPayload(homePayload: envelope.payload)
        let fields = Set(envelope.fields)
        let generated = await generateInsights(payload: payload, fields: fields)
        return HomeInsightsResponse(homeDigest: generated.homeDigest)
    }

    func generateReportsInsights(for envelope: ReportsInsightsEnvelope) async -> ReportsInsightsResponse {
        let payload = LocalInsightsPayload(reportsPayload: envelope.payload)
        let fields = Set(envelope.fields)
        let generated = await generateInsights(payload: payload, fields: fields)
        return ReportsInsightsResponse(
            summary: generated.summary,
            categoryHighlight: generated.categoryHighlight,
            subsAndBills: generated.subsAndBills
        )
    }

    private func generateInsights(payload: LocalInsightsPayload, fields: Set<String>) async -> LocalInsightValues {
        guard hasMeaningfulData(payload: payload, fields: fields) else {
            return .empty
        }

        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .contentTagging)
            if model.isAvailable,
               let modelGenerated = await generateWithAppleIntelligence(payload: payload, fields: fields, model: model),
               modelGenerated.hasAnyValue {
                return modelGenerated
            }
            print("[LocalInsightsService] Apple Intelligence unavailable for insights: \(model.availability)")
        }

        return fallbackInsights(payload: payload, fields: fields)
    }

    @available(iOS 26.0, *)
    private func generateWithAppleIntelligence(payload: LocalInsightsPayload,
                                               fields: Set<String>,
                                               model: SystemLanguageModel) async -> LocalInsightValues? {
        do {
            let session = LanguageModelSession(
                model: model,
                instructions: """
                You write concise, useful financial coaching insights for a mobile expense tracker.
                Return only structured insight fields. Use empty strings when no strong insight exists.
                """
            )

            let response = try await session.respond(
                to: prompt(for: payload, fields: fields),
                generating: LocalInsightGeneration.self,
                options: GenerationOptions(
                    sampling: .greedy,
                    temperature: 0,
                    maximumResponseTokens: 260
                )
            )

            return LocalInsightValues(
                homeDigest: fields.contains("home_digest") ? clean(response.content.homeDigest) : "",
                summary: fields.contains("summary") ? clean(response.content.summary) : "",
                categoryHighlight: fields.contains("category_highlight") ? clean(response.content.categoryHighlight) : "",
                subsAndBills: fields.contains("subs_and_bills") ? clean(response.content.subsAndBills) : ""
            )
        } catch {
            print("[LocalInsightsService] Apple Intelligence insight generation failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func prompt(for payload: LocalInsightsPayload, fields: Set<String>) -> String {
        let projectionText: String
        if let projectionVsBudget = payload.projectionVsBudget {
            projectionText = formatRupees(projectionVsBudget)
        } else {
            projectionText = "unknown"
        }

        let topCategories = payload.category.topCategories
            .prefix(3)
            .map { "\($0.name): \(formatRupees($0.amount)), \($0.sharePercent)%" }
            .joined(separator: "; ")

        let requestedFields = fields.sorted().joined(separator: ", ")

        return """
        Create short Mint app financial insights for these fields: \(requestedFields).

        Rules:
        - Each requested field should be one sentence, max 18 words, or empty if weak.
        - Use rupee symbol values only from this prompt.
        - Do not restate obvious visible totals, list counts, or progress values.
        - Be calm, useful, and specific. No shame or alarm words.

        Data:
        Month: \(payload.summary.monthName) \(payload.summary.year)
        Total expense: \(formatRupees(payload.summary.totalExpense))
        Income: \(formatRupees(payload.summary.totalIncome))
        Daily average: \(formatRupees(payload.summary.dailyAverage))
        Previous daily average: \(payload.summary.previousMonthAverage.map(formatRupees) ?? "none")
        Budget: \(payload.summary.budget.map(formatRupees) ?? "none")
        Projected vs budget: \(projectionText)
        Top categories: \(topCategories.isEmpty ? "none" : topCategories)
        Upcoming bills total: \(formatRupees(payload.subsAndBills.upcomingBillsTotal))
        Next bill: \(payload.subsAndBills.nextBillName ?? "none"), amount \(payload.subsAndBills.nextBillAmount.map(formatRupees) ?? "none"), days until due \(payload.subsAndBills.daysUntilNextBill.map(String.init) ?? "none")
        Monthly subscriptions: \(formatRupees(payload.subsAndBills.monthlySubscriptionTotal))
        Goals: \(payload.goals.map { "\($0.name) \(Int($0.completionPercent.rounded()))%" }.joined(separator: "; "))

        Field meanings:
        homeDigest: pick the single most urgent useful signal across budget, bills, category, or goals.
        summary: focus on budget pace or a concrete next action.
        categoryHighlight: give one behavioral category pattern and a small rule to try.
        subsAndBills: focus on urgent bill prep or subscription audit opportunity.
        """
    }

    private func fallbackInsights(payload: LocalInsightsPayload, fields: Set<String>) -> LocalInsightValues {
        LocalInsightValues(
            homeDigest: fields.contains("home_digest") ? fallbackHomeDigest(payload) : "",
            summary: fields.contains("summary") ? fallbackSummary(payload) : "",
            categoryHighlight: fields.contains("category_highlight") ? fallbackCategory(payload) : "",
            subsAndBills: fields.contains("subs_and_bills") ? fallbackSubsAndBills(payload) : ""
        )
    }

    private func fallbackHomeDigest(_ payload: LocalInsightsPayload) -> String {
        let daysLeft = payload.summary.daysInMonth - payload.summary.daysElapsed

        if let projectionVsBudget = payload.projectionVsBudget,
           projectionVsBudget > 0,
           payload.summary.daysElapsed >= 7 {
            return "At this pace, you may exceed budget by \(formatRupees(projectionVsBudget)); trim one flexible category today."
        }

        if let days = payload.subsAndBills.daysUntilNextBill,
           (0...3).contains(days),
           let name = payload.subsAndBills.nextBillName,
           let amount = payload.subsAndBills.nextBillAmount {
            return "\(formatRupees(amount)) for \(name) is due in \(days) days; transfer a buffer now."
        }

        if let topCategory = payload.category.topCategories.first(where: { $0.sharePercent > 40 }) {
            return "\(topCategory.name) is taking \(topCategory.sharePercent)% of spend; set a weekly ceiling before it drifts."
        }

        if let goal = payload.goals.first(where: { $0.completionPercent >= 90 }) {
            return "\(goal.name) is almost done; one focused top-up can finish the stretch."
        }

        if payload.summary.budget == nil,
           payload.summary.daysElapsed > 0,
           payload.summary.totalExpense > 0,
           daysLeft > 0 {
            let projectedTotal = payload.summary.dailyAverage * Double(payload.summary.daysInMonth)
            return "On current pace, you'll spend \(formatRupees(projectedTotal)) this month across all categories."
        }

        if let goal = payload.goals.first(where: { $0.completionPercent < 30 && $0.target > 0 }) {
            let remaining = goal.target - goal.saved
            return "\(goal.name) still needs \(formatRupees(remaining)); even a small top-up this week builds momentum."
        }

        return ""
    }

    private func fallbackSummary(_ payload: LocalInsightsPayload) -> String {
        let daysLeft = payload.summary.daysInMonth - payload.summary.daysElapsed

        if let projectionVsBudget = payload.projectionVsBudget,
           projectionVsBudget > 0,
           payload.summary.daysElapsed >= 7 {
            return "Projected overspend is \(formatRupees(projectionVsBudget)); one skipped restaurant visit can narrow the gap."
        }

        if let previousAverage = payload.summary.previousMonthAverage,
           previousAverage > payload.summary.dailyAverage,
           previousAverage > 0 {
            let difference = previousAverage - payload.summary.dailyAverage
            return "Your daily pace is \(formatRupees(difference)) below last month; keeping it steady compounds."
        }

        if daysLeft > 5, payload.summary.dailyAverage > 0 {
            let projectedSpend = payload.summary.dailyAverage * Double(payload.summary.daysInMonth)
            if let budget = payload.summary.budget, projectedSpend < budget {
                return "You're currently tracking \(formatRupees(budget - projectedSpend)) under budget for \(payload.summary.monthName)."
            }
            return "Your daily average so far is \(formatRupees(payload.summary.dailyAverage)); \(daysLeft) days left in \(payload.summary.monthName)."
        }

        return ""
    }

    private func fallbackCategory(_ payload: LocalInsightsPayload) -> String {
        guard let topCategory = payload.category.topCategories.first else { return "" }

        if topCategory.sharePercent > 35 {
            return "\(topCategory.name) dominates this month; try a weekly cap to stop quiet drift."
        }

        if payload.category.topCategories.count >= 2 {
            let secondCategory = payload.category.topCategories[1]
            let combinedShare = topCategory.sharePercent + secondCategory.sharePercent
            return "\(topCategory.name) and \(secondCategory.name) together account for \(combinedShare)% of spending this month."
        }

        return "\(topCategory.name) is your top category at \(formatRupees(topCategory.amount)); reviewing it first gives the most leverage."
    }

    private func fallbackSubsAndBills(_ payload: LocalInsightsPayload) -> String {
        if payload.subsAndBills.unpaidBillsCount > 0,
           payload.subsAndBills.upcomingBillsTotal > 0 {
            let billLabel = payload.subsAndBills.unpaidBillsCount == 1 ? "bill" : "bills"
            return "\(payload.subsAndBills.unpaidBillsCount) unpaid \(billLabel) totalling \(formatRupees(payload.subsAndBills.upcomingBillsTotal)) still outstanding this month."
        }

        if let days = payload.subsAndBills.daysUntilNextBill,
           (0...7).contains(days),
           let name = payload.subsAndBills.nextBillName,
           let amount = payload.subsAndBills.nextBillAmount {
            let dayLabel = days == 1 ? "day" : "days"
            return "\(name) needs \(formatRupees(amount)) in \(days) \(dayLabel); move the money before spending elsewhere."
        }

        if payload.subsAndBills.monthlySubscriptionTotal > 0 {
            let annualCost = payload.subsAndBills.monthlySubscriptionTotal * 12
            return "\(formatRupees(payload.subsAndBills.monthlySubscriptionTotal))/month becomes \(formatRupees(annualCost))/year; audit one subscription."
        }

        return ""
    }

    private func hasMeaningfulData(payload: LocalInsightsPayload, fields: Set<String>) -> Bool {
        let checks = [
            "home_digest": payload.summary.totalExpense > 0 ||
                payload.subsAndBills.unpaidBillsCount > 0 ||
                !payload.goals.isEmpty,
            "summary": payload.summary.totalExpense > 0 || payload.summary.totalIncome > 0,
            "category_highlight": payload.category.totalExpense > 0 && !payload.category.topCategories.isEmpty,
            "subs_and_bills": payload.subsAndBills.unpaidBillsCount > 0 ||
                payload.subsAndBills.activeSubscriptionCount > 0
        ]

        return fields.contains { checks[$0] == true }
    }

    private func formatRupees(_ value: Double) -> String {
        if abs(value - value.rounded()) < 0.01 {
            return "₹\(Int(value.rounded()))"
        }
        return String(format: "₹%.2f", value)
    }

    private func clean(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let lowered = cleaned.lowercased()
        let blockedPrefixes = ["could not", "no insight", "n/a", "none", "null"]
        let blockedExactValues = [
            "home digest",
            "home_digest",
            "summary",
            "category highlight",
            "category_highlight",
            "subs and bills",
            "subs_and_bills",
            "goal insight",
            "goal_insight"
        ]

        if cleaned.isEmpty ||
            blockedPrefixes.contains(where: { lowered.hasPrefix($0) }) ||
            blockedExactValues.contains(lowered) {
            return ""
        }

        return cleaned
    }
}

private struct LocalInsightValues {
    var homeDigest: String
    var summary: String
    var categoryHighlight: String
    var subsAndBills: String

    static let empty = LocalInsightValues(homeDigest: "", summary: "", categoryHighlight: "", subsAndBills: "")

    var hasAnyValue: Bool {
        !homeDigest.isEmpty || !summary.isEmpty || !categoryHighlight.isEmpty || !subsAndBills.isEmpty
    }
}

private struct LocalInsightsPayload {
    var summary: Summary
    var category: CategorySection
    var subsAndBills: SubsAndBills
    var goals: [Goal]

    var projectionVsBudget: Double? {
        guard let budget = summary.budget, budget > 0 else { return nil }
        let dailyAverage = summary.totalExpense / Double(max(summary.daysElapsed, 1))
        return (dailyAverage * Double(max(summary.daysInMonth, 1))) - budget
    }

    init(homePayload: HomeInsightsPayload) {
        summary = Summary(homePayload.summary)
        category = CategorySection(homePayload.category)
        subsAndBills = SubsAndBills(homePayload.subsAndBills)
        goals = homePayload.goals.map(Goal.init)
    }

    init(reportsPayload: ReportsInsightsPayload) {
        summary = Summary(reportsPayload.summary)
        category = CategorySection(reportsPayload.category)
        subsAndBills = SubsAndBills(reportsPayload.subsAndBills)
        goals = []
    }

    struct Summary {
        var monthName: String
        var year: Int
        var daysElapsed: Int
        var daysInMonth: Int
        var totalExpense: Double
        var totalIncome: Double
        var dailyAverage: Double
        var previousMonthAverage: Double?
        var budget: Double?

        nonisolated init(_ summary: HomeInsightsPayload.SummarySection) {
            monthName = summary.monthName
            year = summary.year
            daysElapsed = summary.daysElapsed
            daysInMonth = summary.daysInMonth
            totalExpense = summary.totalExpense
            totalIncome = summary.totalIncome
            dailyAverage = summary.dailyAverage
            previousMonthAverage = summary.previousMonthAverage
            budget = summary.budget
        }

        nonisolated init(_ summary: ReportsInsightsPayload.SummarySection) {
            monthName = summary.monthName
            year = summary.year
            daysElapsed = summary.daysElapsed
            daysInMonth = summary.daysInMonth
            totalExpense = summary.totalExpense
            totalIncome = summary.totalIncome
            dailyAverage = summary.dailyAverage
            previousMonthAverage = summary.previousMonthAverage
            budget = summary.budget
        }
    }

    struct CategorySection {
        var totalExpense: Double
        var topCategories: [CategoryItem]

        nonisolated init(_ category: HomeInsightsPayload.CategorySection) {
            totalExpense = category.totalExpense
            topCategories = category.topCategories.map(CategoryItem.init)
        }

        nonisolated init(_ category: ReportsInsightsPayload.CategorySection) {
            totalExpense = category.totalExpense
            topCategories = category.topCategories.map(CategoryItem.init)
        }
    }

    struct CategoryItem {
        var name: String
        var amount: Double
        var sharePercent: Int

        nonisolated init(_ category: HomeInsightsPayload.CategoryItem) {
            name = category.name
            amount = category.amount
            sharePercent = category.sharePercent
        }

        nonisolated init(_ category: ReportsInsightsPayload.CategoryItem) {
            name = category.name
            amount = category.amount
            sharePercent = category.sharePercent
        }
    }

    struct SubsAndBills {
        var unpaidBillsCount: Int
        var upcomingBillsTotal: Double
        var nextBillName: String?
        var nextBillAmount: Double?
        var daysUntilNextBill: Int?
        var activeSubscriptionCount: Int
        var monthlySubscriptionTotal: Double

        nonisolated init(_ subsAndBills: HomeInsightsPayload.SubsAndBillsSection) {
            unpaidBillsCount = subsAndBills.unpaidBillsCount
            upcomingBillsTotal = subsAndBills.upcomingBillsTotal
            nextBillName = subsAndBills.nextBillName
            nextBillAmount = subsAndBills.nextBillAmount
            daysUntilNextBill = subsAndBills.daysUntilNextBill
            activeSubscriptionCount = subsAndBills.activeSubscriptionCount
            monthlySubscriptionTotal = subsAndBills.monthlySubscriptionTotal
        }

        nonisolated init(_ subsAndBills: ReportsInsightsPayload.SubsAndBillsSection) {
            unpaidBillsCount = subsAndBills.unpaidBillsCount
            upcomingBillsTotal = subsAndBills.upcomingBillsTotal
            nextBillName = subsAndBills.nextBillName
            nextBillAmount = subsAndBills.nextBillAmount
            daysUntilNextBill = subsAndBills.daysUntilNextBill
            activeSubscriptionCount = subsAndBills.activeSubscriptionCount
            monthlySubscriptionTotal = subsAndBills.monthlySubscriptionTotal
        }
    }

    struct Goal {
        var name: String
        var target: Double
        var saved: Double

        var completionPercent: Double {
            guard target > 0 else { return 0 }
            return min(100, (saved / target) * 100)
        }

        nonisolated init(_ goal: HomeInsightsPayload.GoalItem) {
            name = goal.name
            target = goal.target
            saved = goal.saved
        }
    }
}
