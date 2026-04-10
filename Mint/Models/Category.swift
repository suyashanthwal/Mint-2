//
//  Category.swift
//  DataModel
//
//  Created by Anushk on 04/02/26.
//

import Foundation

enum CategoryType: String, Codable, CaseIterable {
    case expense
    case income
}

struct Category: Identifiable, Codable {

    let id: UUID
    var name: String
    var color: String
    var icon: String
    var budget: Double
    var type: CategoryType
    var remaining: Double
    var isOver: Bool
    var percentageUsed: Double
    
    init(id: UUID = UUID(),
         name: String,
         color: String,
         icon: String,
         budget: Double = 0,
         type: CategoryType = .expense,
         remaining: Double = 0,
         isOver: Bool = false,
         percentageUsed: Double = 0) {
        
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.budget = budget
        self.type = type
        self.remaining = remaining
        self.isOver = isOver
        self.percentageUsed = percentageUsed
    }
}
