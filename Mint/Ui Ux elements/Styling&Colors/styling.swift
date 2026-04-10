//  styling.swift
//  JustChecking
//
//  Created by Suyash Anthwal on 22/03/26.
//

import UIKit

extension UIView {
    func applyShadow() {
        self.layer.cornerRadius  = 12.0
        self.layer.shadowColor   = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.05
        self.layer.shadowOffset  = CGSize(width: 0, height: 1)
        self.layer.shadowRadius  = 1
        self.layer.masksToBounds = false
    }
}

// MARK: - Circular Progress Bar

class CircularProgressView {
    
    private var progressLayer = CAShapeLayer()
    private var trackLayer    = CAShapeLayer()
    
    func setupCircularProgress(
        on view: UIView,
        progress: CGFloat,
        trackColor: UIColor    = UIColor.lightGray.withAlphaComponent(0.3),
        progressColor: UIColor = UIColor(red: 0.27, green: 0.45, blue: 0.31, alpha: 1.0),
        lineWidth: CGFloat     = 8.0
    ) {
        progressLayer.removeFromSuperlayer()
        trackLayer.removeFromSuperlayer()
        
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let radius = (min(view.bounds.width, view.bounds.height) / 2) - (lineWidth / 2)
        
        let circularPath = UIBezierPath(
            arcCenter:  center,
            radius:     radius,
            startAngle: -CGFloat.pi / 2,
            endAngle:   3 * CGFloat.pi / 2,
            clockwise:  true
        )
        
        trackLayer.path        = circularPath.cgPath
        trackLayer.fillColor   = UIColor.clear.cgColor
        trackLayer.strokeColor = trackColor.cgColor
        trackLayer.lineWidth   = lineWidth
        trackLayer.lineCap     = .round
        view.layer.addSublayer(trackLayer)
        
        progressLayer.path        = circularPath.cgPath
        progressLayer.fillColor   = UIColor.clear.cgColor
        progressLayer.strokeColor = progressColor.cgColor
        progressLayer.lineWidth   = lineWidth
        progressLayer.lineCap     = .round
        progressLayer.strokeEnd   = 0
        view.layer.addSublayer(progressLayer)
        
        animateProgress(to: progress)
    }
    
    func animateProgress(to value: CGFloat, duration: TimeInterval = 1.2) {
        let clampedValue = max(0, min(1, value))
        let animation                    = CABasicAnimation(keyPath: "strokeEnd")
        animation.toValue                = clampedValue
        animation.duration               = duration
        animation.fillMode               = .forwards
        animation.isRemovedOnCompletion  = false
        animation.timingFunction         = CAMediaTimingFunction(name: .easeInEaseOut)
        progressLayer.add(animation, forKey: "progressAnimation")
    }
}

// MARK: - Currency Formatter

let currencyFormatter: NumberFormatter = {
    let f            = NumberFormatter()
    f.numberStyle    = .currency
    f.currencyCode   = "INR"
    f.locale         = Locale(identifier: "en_IN")
    return f
}()

// MARK: - Card Icon View Style
// Styles the round icon background seen on every report card

extension UIView {
    /// Applies the green tinted circular background used for card icons
    func applyCardIconStyle() {
        self.backgroundColor    = AppColors.brandLight.withAlphaComponent(0.4)
        self.layer.cornerRadius = self.bounds.width / 2
        self.clipsToBounds      = true
    }
}

// MARK: - Progress Bar Style
// Two flavours: brand green (income / budget) and red (expense / over-budget)

extension UIProgressView {
    func applyBrandStyle() {
        self.progressTintColor = AppColors.brand
        self.trackTintColor    = AppColors.brandLight.withAlphaComponent(0.4)
        self.layer.cornerRadius = self.bounds.height / 2
        self.clipsToBounds      = true
    }

    func applyExpenseStyle() {
        self.progressTintColor  = AppColors.error
        self.trackTintColor     = AppColors.brandLight.withAlphaComponent(0.4)
        self.layer.cornerRadius = self.bounds.height / 2
        self.clipsToBounds      = true
    }
}

// MARK: - Pill / Chip Badge
// Creates the grey rounded pill labels seen on the Subscriptions & Bills card

extension UIView {
    /// Wraps the view in a pill-shaped badge style (used for "4 Active", "₹2,400 Monthly")
    func applyPillStyle() {
        self.backgroundColor    = AppColors.sectionBackground
        self.layer.cornerRadius = 14
        self.clipsToBounds      = true
    }
}

// MARK: - Calendar Styles
// Used by SubsCalendarView and SubsCalenderCollectionViewCell

extension UIView {

    /// The outer card container for the calendar (white card, rounded, shadow).
    func applyCalendarCardStyle() {
        backgroundColor    = AppColors.card
        layer.cornerRadius = 16
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.05
        layer.shadowOffset  = CGSize(width: 0, height: 1)
        layer.shadowRadius  = 4
        layer.masksToBounds = false
        clipsToBounds       = false
    }

    /// Today's date cell — brand-green filled rounded square.
    func applyCalendarTodayStyle() {
        backgroundColor    = AppColors.brand
        layer.cornerRadius = 12
        clipsToBounds      = true
    }

    /// Empty or padding cell — transparent, no rounding.
    func applyCalendarEmptyStyle() {
        backgroundColor    = .clear
        layer.cornerRadius = 0
        clipsToBounds      = false
    }

    /// Small circular dot indicator — used under dates that have a bill.
    func applyDotStyle() {
        backgroundColor    = AppColors.brand
        layer.cornerRadius = bounds.height / 2
        clipsToBounds      = true
    }
}

// MARK: - Attributed description helpers
// Used for the subtitle lines inside cards that mix normal + coloured text

extension NSMutableAttributedString {

    /// Appends a run of text in the brand green colour — used to highlight
    /// values like "Food & Dining" in the Category Breakdown subtitle.
    @discardableResult
    func appendBrand(_ text: String, font: UIFont? = nil) -> NSMutableAttributedString {
        var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: AppColors.brand]
        if let f = font { attrs[.font] = f }
        append(NSAttributedString(string: text, attributes: attrs))
        return self
    }

    /// Appends a normal secondary-coloured run of text.
    @discardableResult
    func appendSecondary(_ text: String, font: UIFont? = nil) -> NSMutableAttributedString {
        var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: AppColors.textSecondary]
        if let f = font { attrs[.font] = f }
        append(NSAttributedString(string: text, attributes: attrs))
        return self
    }
}
