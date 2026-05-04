
import UIKit

enum AppColors {
    static let accent           = UIColor(named: "AccentColor") ?? UIColor(hex: "#7C2DFF")

    static let background        = UIColor(hex: "#070819")
    
    static let card              = UIColor(hex: "#121A34")

    static let sectionBackground = UIColor(hex: "#0B0D21")

    static let inputBackground   = UIColor(hex: "#1A2442")

    static let brand             = accent

    static let brandLight        = accent.withAlphaComponent(0.24)

    static let budgetBreakdownBackground = UIColor(hex: "#171333")

    static let budgetBreakdownCard = UIColor(hex: "#32117D")

    static let budgetBreakdownBorder = UIColor(hex: "#7C2DFF")

    static let brandText         = UIColor(hex: "#ffffff")

    static let brandLightText    = UIColor(hex: "#F6F1FF")

    static let textPrimary       = UIColor(hex: "#F7F7FF")

    static let textSecondary     = UIColor(hex: "#D7D6F0")

    static let error             = UIColor(hex: "#FF5A68")

    static let errorBackground   = UIColor(hex: "#301526")
    
    static let errorText         = UIColor(hex: "#FFE6EA")

    static let cardBorder        = UIColor(hex: "#2A3B76")

    static let orange            = UIColor(hex: "#FF8A00")

    static let success           = UIColor(hex: "#34D26D")

    static let brandGradient: [CGColor] = [
        accent.withAlphaComponent(0.78).cgColor,
        accent.cgColor
    ]

    static let goalGradient: [CGColor] = [
        UIColor(hex: "#6AA85A").cgColor,
        UIColor(hex: "#C7E8C9").cgColor
    ]
}

extension UIColor {
        func lighter(by percentage: CGFloat = 0.85) -> UIColor {
            return self.withAlphaComponent(percentage)
        }

    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.hasPrefix("#") ? String(s.dropFirst()) : s
        var val: UInt64 = 0
        Scanner(string: s).scanHexInt64(&val)
        self.init(
            red:   CGFloat((val & 0xFF0000) >> 16) / 255,
            green: CGFloat((val & 0x00FF00) >> 8)  / 255,
            blue:  CGFloat( val & 0x0000FF)         / 255,
            alpha: 1.0
        )
    }
}
