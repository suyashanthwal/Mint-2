//
//  User.swift
//  DataModel
//
//  Created by Anushk on 04/02/26.
//

import Foundation


struct User: Codable {
    
    var name: String
    var phoneNumber: String
    var email: String
    var isEmailAutoForward: Bool
    var currency: String
    var isPinEnabled: Bool
    var isBiometricEnabled: Bool
    var isDarkModeEnabled: Bool
    var isNotificationEnabled: Bool
    var profileImageName: String?
    var createdOn: Date
    var categories: [Category]
    var goals: [Goal]
    var recurringPayments: [RecurringPayment]
    var transactions: [Transaction]
    var bills: [Bill]
    var receipts: [Receipt]
    var budgets: [Budget]
    
    init(name: String,
         phoneNumber: String,
         email: String,
         currency: String = "INR",
         isEmailAutoForward: Bool = false,
         isPinEnabled: Bool = false,
         isBiometricEnabled: Bool = false,
         isDarkModeEnabled: Bool = false,
         isNotificationEnabled: Bool = true,
         profileImageName: String? = nil) {
        
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        self.currency = currency
        self.isEmailAutoForward = isEmailAutoForward
        self.isPinEnabled = isPinEnabled
        self.isBiometricEnabled = isBiometricEnabled
        self.isDarkModeEnabled = isDarkModeEnabled
        self.isNotificationEnabled = isNotificationEnabled
        self.profileImageName = profileImageName
        self.createdOn = Date()
        
        self.categories = []
        self.goals = []
        self.recurringPayments = []
        self.transactions = []
        self.bills = []
        self.receipts = []
        self.budgets = []
    }
}
