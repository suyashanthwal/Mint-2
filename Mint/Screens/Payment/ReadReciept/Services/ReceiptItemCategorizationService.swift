import Foundation
import FoundationModels

@available(iOS 26.0, *)
@Generable(description: "Category assignments for receipt line items.")
private struct ReceiptCategorySuggestionBatch {
    let assignments: [ReceiptCategorySuggestion]
}

@available(iOS 26.0, *)
@Generable(description: "A category assignment for one receipt line item.")
private struct ReceiptCategorySuggestion {
    let index: Int
    let categoryName: String
}

final class ReceiptItemCategorizationService {

    static let shared = ReceiptItemCategorizationService()
    private init() {}

    func categorize(lineItems: [ReceiptLineItem],
                    merchantName: String?,
                    categories: [Category]) async -> [Int: Category] {
        guard !lineItems.isEmpty, !categories.isEmpty else { return [:] }

        let heuristicAssignments = heuristicAssignments(for: lineItems, categories: categories)

        guard #available(iOS 26.0, *) else {
            return heuristicAssignments
        }

        let model = SystemLanguageModel(useCase: .contentTagging)
        guard model.isAvailable else {
            print("[ReceiptItemCategorizationService] Apple Intelligence unavailable: \(model.availability)")
            return heuristicAssignments
        }

        let categoryLookup = Dictionary(
            uniqueKeysWithValues: categories.map { (normalizedCategoryName($0.name), $0) }
        )

        let categoryList = categories.map(\.name).joined(separator: ", ")
        let merchantLine = merchantName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? merchantName!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "Unknown merchant"

        let itemLines = lineItems.enumerated().map { index, item in
            let quantityDescription: String
            if let quantity = item.quantity {
                quantityDescription = quantity.rounded() == quantity ? String(Int(quantity)) : String(format: "%.2f", quantity)
            } else {
                quantityDescription = "unknown"
            }

            let unitPriceDescription = item.unitPrice.map { String(format: "₹%.2f", $0) } ?? "unknown"
            let totalPriceDescription = item.totalPrice.map { String(format: "₹%.2f", $0) } ?? "unknown"

            return "\(index). \(item.name) | quantity: \(quantityDescription) | unit price: \(unitPriceDescription) | total: \(totalPriceDescription)"
        }.joined(separator: "\n")

        let prompt = """
        Categorize each receipt line item into one of the user's existing categories.

        Rules:
        - Use exactly one of the provided category names.
        - Return one assignment for every item index.
        - Never invent a new category name.
        - Prefer semantic meaning of the purchased item over string matching.
        - If uncertain, choose the closest everyday spending category from the provided list.

        Merchant: \(merchantLine)
        Allowed categories: \(categoryList)

        Receipt items:
        \(itemLines)
        """

        do {
            let session = LanguageModelSession(
                model: model,
                instructions: """
                You classify shopping receipt items into the user's existing budget categories.
                Reply only with structured category assignments using the provided schema.
                """
            )

            let response = try await session.respond(
                to: prompt,
                generating: ReceiptCategorySuggestionBatch.self,
                options: GenerationOptions(
                    sampling: .greedy,
                    temperature: 0,
                    maximumResponseTokens: 400
                )
            )

            var resolvedAssignments = heuristicAssignments
            for suggestion in response.content.assignments {
                guard lineItems.indices.contains(suggestion.index),
                      let category = categoryLookup[normalizedCategoryName(suggestion.categoryName)] else {
                    continue
                }
                resolvedAssignments[suggestion.index] = category
            }

            return resolvedAssignments
        } catch {
            print("[ReceiptItemCategorizationService] Apple Intelligence categorization failed: \(error.localizedDescription)")
            return heuristicAssignments
        }
    }

    private func heuristicAssignments(for lineItems: [ReceiptLineItem],
                                      categories: [Category]) -> [Int: Category] {
        var assignments: [Int: Category] = [:]

        for (index, item) in lineItems.enumerated() {
            let normalizedItemName = normalizedItemText(item.name)

            if let directMatch = categories.first(where: {
                normalizedItemName.contains(normalizedCategoryName($0.name))
            }) {
                assignments[index] = directMatch
                continue
            }

            if let tokenMatch = categories.first(where: { category in
                let categoryTokens = Set(normalizedCategoryName(category.name).split(separator: " ").map(String.init))
                let itemTokens = Set(normalizedItemName.split(separator: " ").map(String.init))
                return !categoryTokens.isEmpty && !itemTokens.isDisjoint(with: categoryTokens)
            }) {
                assignments[index] = tokenMatch
                continue
            }

            if let firstCategory = categories.first {
                assignments[index] = firstCategory
            }
        }

        return assignments
    }

    private func normalizedItemText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "&", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func normalizedCategoryName(_ name: String) -> String {
        normalizedItemText(name)
    }
}
