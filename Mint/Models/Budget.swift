//
//  Budget.swift
//  DataModel
//
//  Created by Anushk on 04/02/26.
//

import Foundation

struct Budget: Identifiable, Codable {

    let id: UUID
    var allocatedBudget: Double
    var totalExpense: Double
    var dailyLimit: Double
    var lastResetDate: String       // "YYYY-MM-DD" — matches last_reset_date in DB
    var categoryIds: Set<UUID>

    // Derived — never stored
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
