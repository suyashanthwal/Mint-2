//
//  RecurringPayment.swift
//  DataModel
//
//  Created by Anushk on 04/02/26.
//

import Foundation

enum PaymentDuration: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly
    case yearly
}

struct RecurringPayment: Identifiable, Codable {
    
    let id: UUID
    var name: String
    var categoryId: UUID?
    var duration: PaymentDuration
    var amount: Double
    var lastDate: Date?
    var nextDate: Date
    var isActive: Bool
    var isAlertEnabled: Bool
    var isAddAutomatically: Bool
    var repeatCount: Int
    var totalAmount: Double
    var icon: String?
    var note: String?
    var isIncome: Bool
    
    init(id: UUID = UUID(),
         name: String,
         categoryId: UUID? = nil,
         duration: PaymentDuration,
         amount: Double,
         nextDate: Date,
         isActive: Bool = true,
         isAlertEnabled: Bool = true,
         isAddAutomatically: Bool = true,
         repeatCount: Int = 0,
         totalAmount: Double = 0,
         icon: String? = nil,
         note: String? = nil,
         isIncome: Bool = false,
         lastDate: Date? = nil) {
        
        self.id = id
        self.name = name
        self.categoryId = categoryId
        self.duration = duration
        self.amount = amount
        self.nextDate = nextDate
        self.isActive = isActive
        self.isAlertEnabled = isAlertEnabled
        self.isAddAutomatically = isAddAutomatically
        self.repeatCount = repeatCount
        self.totalAmount = totalAmount
        self.icon = icon
        self.note = note
        self.isIncome = isIncome
        self.lastDate = lastDate
    }
}
