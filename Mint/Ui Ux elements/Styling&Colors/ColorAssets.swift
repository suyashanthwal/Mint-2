//  ColorAssets.swift
//  BudgetApp

import UIKit

enum AppColors {
    static let background        = UIColor(hex: "#f8faf8")
    
    static let card              = UIColor(hex: "#ffffff")

    static let sectionBackground = UIColor(hex: "#f1f4f2")


    static let inputBackground   = UIColor(hex: "#e4e9e7")


    static let brand             = UIColor(hex: "#406845")

    static let brandLight        = UIColor(hex: "#c3e8ca")

    static let brandText         = UIColor(hex: "#ffffff")

    static let brandLightText    = UIColor(hex: "#1a3b1f")


    static let textPrimary       = UIColor(hex: "#2d3432")

    static let textSecondary     = UIColor(hex: "#59615f")


    static let error             = UIColor(hex: "#b3261e")

    static let errorBackground   = UIColor(hex: "#f9dedc")
    
    static let errorText         = UIColor(hex: "#410e0b")

    static let brandGradient: [CGColor] = [
        UIColor(hex: "#406845").cgColor,
        UIColor(hex: "#345c3a").cgColor
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
