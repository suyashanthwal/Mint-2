import UIKit
import Foundation

struct CategoryData {

    static let colors: [UIColor] = [
        UIColor(red: 1.0, green: 0.93, blue: 0.0, alpha: 1.0),
        UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 1.0),
        UIColor(red: 1.0, green: 0.0, blue: 0.55, alpha: 1.0),
        UIColor(red: 0.0, green: 0.85, blue: 0.0, alpha: 1.0),
        UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0),
        UIColor(red: 0.55, green: 0.0, blue: 1.0, alpha: 1.0)
    ]

    static let iconCategories: [String: [String]] = [
        "Food & Dining": [
            "fork.knife", "cup.and.saucer", "wineglass",
            "birthday.cake", "takeoutbag.and.cup.and.straw",
            "carrot", "leaf", "flame", "cart"
        ],

        "Transport": [
            "car", "bus", "bicycle", "airplane",
            "tram", "ferry", "fuelpump", "parkingsign"
        ],

        "Shopping / Lifestyle": [
            "bag", "cart", "giftcard", "tshirt",
            "eyeglasses", "theatermasks", "film",
            "guitars", "book", "house"
        ],

        "Health & Fitness": [
            "heart", "cross.case", "figure.walk",
            "figure.run", "dumbbell", "sportscourt",
            "bed.double", "pills"
       ]
    ]

    static let subsAndBillsIconCategories: [String: [String]] = [
        "Streaming & Media": [
            "play.rectangle.fill", "tv.fill", "music.note",
            "gamecontroller.fill", "book.fill", "newspaper.fill",
            "headphones", "film.fill", "antenna.radiowaves.left.and.right"
        ],

        "Utilities": [
            "bolt.fill", "drop.fill", "flame.fill", "wifi",
            "phone.fill", "lightbulb.fill", "trash.fill",
            "house.fill"
        ],

        "Finance & Services": [
            "creditcard.fill", "doc.text.fill", "banknote.fill",
            "building.columns.fill", "lock.shield.fill", "cross.case.fill",
            "car.fill", "bus.fill", "fuelpump.fill", "wrench.fill"
        ],

        "Home & Essentials": [
            "cart.fill", "bag.fill", "basket.fill", "fork.knife",
            "cup.and.saucer.fill", "shippingbox.fill", "giftcard.fill",
            "calendar.badge.clock"
       ]
    ]
}
