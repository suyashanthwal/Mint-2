//  ColorAssets.swift
//  BudgetApp

import UIKit

// ─────────────────────────────────────────────
//  HOW TO USE
//  view.backgroundColor = AppColors.background
//  label.textColor      = AppColors.textPrimary
//  button.backgroundColor = AppColors.brand
// ─────────────────────────────────────────────

enum AppColors {

    // MARK: - Backgrounds
    // Use these for the background of screens and containers

    /// The main screen background (off-white, very light green tint)
    static let background        = UIColor(hex: "#f8faf8")
    /// Cards and floating elements (pure white — pops above background)
    static let card              = UIColor(hex: "#ffffff")

    /// Section backgrounds, list group headers (slightly darker than background)
    static let sectionBackground = UIColor(hex: "#f1f4f2")

    /// Input fields and search bars (deeper inset feel)
    static let inputBackground   = UIColor(hex: "#e4e9e7")


    // MARK: - Brand (Pistachio Green)
    // Use these for buttons, highlights, and interactive elements

    /// Primary brand color — use for main buttons, icons, highlights
    static let brand             = UIColor(hex: "#406845")

    /// Light version of brand — use for secondary/outline button backgrounds
    static let brandLight        = UIColor(hex: "#c3e8ca")

    /// Text color on top of a brand-colored background (e.g. button label)
    static let brandText         = UIColor(hex: "#ffffff")

    /// Text color on top of brandLight background
    static let brandLightText    = UIColor(hex: "#1a3b1f")


    // MARK: - Text
    // Use these for all labels and text

    /// Main text — headlines, body copy (soft black, never pure #000)
    static let textPrimary       = UIColor(hex: "#2d3432")

    /// Subtle text — placeholders, captions, secondary info
    static let textSecondary     = UIColor(hex: "#59615f")


    // MARK: - Error / Alerts
    // Use these for validation errors or warning messages

    /// Error color — red tint for alerts
    static let error             = UIColor(hex: "#b3261e")

    /// Background behind an error message
    static let errorBackground   = UIColor(hex: "#f9dedc")

    /// Text shown inside an error background
    static let errorText         = UIColor(hex: "#410e0b")


    // MARK: - Gradient (for Primary Buttons)
    // Apply via CAGradientLayer — see example below

    /*
     EXAMPLE — Gradient primary button:

        let grad = CAGradientLayer()
        grad.colors     = AppColors.brandGradient
        grad.startPoint = CGPoint(x: 0.15, y: 0)
        grad.endPoint   = CGPoint(x: 0.85, y: 1)
        grad.frame      = myButton.bounds
        grad.cornerRadius = 12
        myButton.layer.insertSublayer(grad, at: 0)
    */
    static let brandGradient: [CGColor] = [
        UIColor(hex: "#406845").cgColor,  // top
        UIColor(hex: "#345c3a").cgColor   // bottom
    ]
}


// ─────────────────────────────────────────────
//  QUICK REFERENCE CHEAT SHEET
//
//  Screen background      → AppColors.background
//  White card             → AppColors.card
//  Section / group row    → AppColors.sectionBackground
//  Text field background  → AppColors.inputBackground
//
//  Brand button fill      → AppColors.brand
//  Brand button label     → AppColors.brandText
//  Secondary button fill  → AppColors.brandLight
//  Secondary button label → AppColors.brandLightText
//
//  Headline / body text   → AppColors.textPrimary
//  Caption / placeholder  → AppColors.textSecondary
//
//  Error message text     → AppColors.error
//  Error banner bg        → AppColors.errorBackground
//  Error banner text      → AppColors.errorText
// ─────────────────────────────────────────────


// MARK: - Hex helper (no need to touch this)

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
