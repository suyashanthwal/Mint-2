//
//  Bill.swift
//  DataModel
//
//  Created by Anushk on 04/02/26.
//

import Foundation

enum BillingRange: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly
    case yearly
}

struct Bill: Identifiable, Codable {
    
    let id: UUID
    let icon: String
    var name: String
    var categoryId: UUID
    var amount: Double
    var billDate: Date
    var range: BillingRange
    var isPaid: Bool
    var isAlertEnabled: Bool
    var note: String?
    var createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         icon: String,
         categoryId: UUID,
         amount: Double,
         billDate: Date,
         range: BillingRange,
         isPaid: Bool = false,
         isAlertEnabled: Bool = true,
         note: String? = nil) {
        
        self.id = id
        self.icon = icon
        self.name = name
        self.categoryId = categoryId
        self.amount = amount
        self.billDate = billDate
        self.range = range
        self.isPaid = isPaid
        self.isAlertEnabled = isAlertEnabled
        self.note = note
        self.createdAt = Date()
    }
}
