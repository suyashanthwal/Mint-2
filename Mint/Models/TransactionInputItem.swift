import UIKit

enum TransactionInputType {
    case category
    case account
    case note
    case date
    case repeatOption
}

struct TransactionInputItem {
    let type: TransactionInputType
    let icon: String // SF Symbol name
    let title: String
    var value: String
    let hasAccessory: Bool
    
    static func defaultItems() -> [TransactionInputItem] {
        return [
            TransactionInputItem(type: .category, icon: "square.grid.2x2", title: "Category", value: "Miscellaneous", hasAccessory: true),
            TransactionInputItem(type: .account, icon: "wallet.pass", title: "From:", value: "Savings", hasAccessory: true),
            TransactionInputItem(type: .note, icon: "pencil", title: "Note:", value: "", hasAccessory: false),
            TransactionInputItem(type: .date, icon: "calendar", title: "Today:", value: "", hasAccessory: true),
            TransactionInputItem(type: .repeatOption, icon: "repeat", title: "Never Repeat", value: "", hasAccessory: true)
        ]
    }
}
