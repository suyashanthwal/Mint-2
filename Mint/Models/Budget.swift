
import Foundation

struct Budget: Identifiable, Codable {

    let id: UUID
    var allocatedBudget: Double
    var totalExpense: Double
    var dailyLimit: Double
    var lastResetDate: String
    var categoryIds: Set<UUID>

    var remainingBudget: Double { allocatedBudget - totalExpense }

    init(id: UUID = UUID(),
         allocatedBudget: Double,
         totalExpense: Double = 0,
         dailyLimit: Double,
         lastResetDate: String,
         categoryIds: Set<UUID> = []) {

        self.id              = id
        self.allocatedBudget = allocatedBudget
        self.totalExpense    = totalExpense
        self.dailyLimit      = dailyLimit
        self.lastResetDate   = lastResetDate
        self.categoryIds     = categoryIds
    }
}
