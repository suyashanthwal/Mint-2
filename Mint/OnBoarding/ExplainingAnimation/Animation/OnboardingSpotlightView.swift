//
//  OnboardingSpotlightView.swift
//  JustChecking
//
//  Created by Suyash Anthwal on 22/03/26.
//

import UIKit

// MARK: - Step Model

struct OnboardingStep {
    let view: UIView
    let title: String
    let message: String
    let tooltipBelow: Bool
}

// MARK: - OnboardingSpotlightView

final class OnboardingSpotlightView: UIView {

    var onTap: (() -> Void)?

    // MARK: - Style Constants (from styling.swift)

    private enum Style {
        static let accentGreen      = UIColor(red: 0.27, green: 0.45, blue: 0.31, alpha: 1.0) // #456E4F
        static let accentGreenLight = UIColor(red: 0.27, green: 0.45, blue: 0.31, alpha: 0.15)
        static let cornerRadius: CGFloat  = 12.0
        static let shadowColor            = UIColor.black.cgColor
        static let shadowOpacity: Float   = 0.05
        static let shadowOffset           = CGSize(width: 0, height: 1)
        static let shadowRadius: CGFloat  = 1
    }

    // MARK: - Private Views

    private let maskLayer = CAShapeLayer()
    private let dimView   = UIView()

    private let tooltipContainer: UIView = {
        let v = UIView()
        v.backgroundColor               = .white
        v.layer.cornerRadius            = Style.cornerRadius
        v.layer.shadowColor             = Style.shadowColor
        v.layer.shadowOpacity           = Style.shadowOpacity
        v.layer.shadowOffset            = Style.shadowOffset
        v.layer.shadowRadius            = Style.shadowRadius
        v.layer.masksToBounds           = false
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alpha = 0
        return v
    }()

    private let accentBar: UIView = {
        let v = UIView()
        v.backgroundColor    = Style.accentGreen
        v.layer.cornerRadius = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let stepBadge: UILabel = {
        let l = UILabel()
        l.font      = UIFont.systemFont(ofSize: 11, weight: .semibold)
        l.textColor = Style.accentGreen
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let tooltipTitle: UILabel = {
        let l = UILabel()
        l.font      = UIFont.systemFont(ofSize: 17, weight: .bold)
        l.textColor = UIColor.black
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let tooltipMessage: UILabel = {
        let l = UILabel()
        l.font          = UIFont.systemFont(ofSize: 14, weight: .regular)
        l.textColor     = UIColor.gray
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let divider: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let progressStack: UIStackView = {
        let s = UIStackView()
        s.axis      = .horizontal
        s.spacing   = 6
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let tapHint: UILabel = {
        let l = UILabel()
        l.text          = "Tap anywhere to continue"
        l.font          = UIFont.systemFont(ofSize: 12, weight: .medium)
        l.textColor     = UIColor.lightGray
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var tooltipTopConstraint: NSLayoutConstraint?
    private var tooltipBottomConstraint: NSLayoutConstraint?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        backgroundColor = .clear

        // Dim layer with cutout mask
        dimView.frame            = bounds
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimView.backgroundColor  = UIColor.black.withAlphaComponent(0.55)
        dimView.layer.mask       = maskLayer
        addSubview(dimView)

        // Tooltip internals
        tooltipContainer.addSubview(accentBar)
        tooltipContainer.addSubview(stepBadge)
        tooltipContainer.addSubview(tooltipTitle)
        tooltipContainer.addSubview(tooltipMessage)
        tooltipContainer.addSubview(divider)
        tooltipContainer.addSubview(progressStack)
        addSubview(tooltipContainer)
        addSubview(tapHint)

        NSLayoutConstraint.activate([
            // Accent bar — left edge of tooltip
            accentBar.topAnchor.constraint(equalTo: tooltipContainer.topAnchor, constant: 16),
            accentBar.bottomAnchor.constraint(equalTo: tooltipContainer.bottomAnchor, constant: -16),
            accentBar.leadingAnchor.constraint(equalTo: tooltipContainer.leadingAnchor, constant: 16),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            // Step badge
            stepBadge.topAnchor.constraint(equalTo: tooltipContainer.topAnchor, constant: 16),
            stepBadge.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),

            // Title
            tooltipTitle.topAnchor.constraint(equalTo: stepBadge.bottomAnchor, constant: 4),
            tooltipTitle.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            tooltipTitle.trailingAnchor.constraint(equalTo: tooltipContainer.trailingAnchor, constant: -16),

            // Message
            tooltipMessage.topAnchor.constraint(equalTo: tooltipTitle.bottomAnchor, constant: 6),
            tooltipMessage.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            tooltipMessage.trailingAnchor.constraint(equalTo: tooltipContainer.trailingAnchor, constant: -16),

            // Divider
            divider.topAnchor.constraint(equalTo: tooltipMessage.bottomAnchor, constant: 14),
            divider.leadingAnchor.constraint(equalTo: tooltipContainer.leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: tooltipContainer.trailingAnchor, constant: -16),
            divider.heightAnchor.constraint(equalToConstant: 1),

            // Progress dots
            progressStack.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),
            progressStack.centerXAnchor.constraint(equalTo: tooltipContainer.centerXAnchor),
            progressStack.bottomAnchor.constraint(equalTo: tooltipContainer.bottomAnchor, constant: -14),
            progressStack.heightAnchor.constraint(equalToConstant: 8),

            // Tooltip horizontal
            tooltipContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            tooltipContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            // Tap hint
            tapHint.centerXAnchor.constraint(equalTo: centerXAnchor),
            tapHint.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -44),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
    }

    // MARK: - Public API

    func configure(totalSteps: Int) {
        progressStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for _ in 0..<totalSteps {
            progressStack.addArrangedSubview(makeDot(active: false))
        }
    }

    func spotlight(
        on targetView: UIView,
        title: String,
        message: String,
        stepIndex: Int,
        tooltipBelow: Bool,
        animated: Bool = true
    ) {
        // --- Cutout ---
        let targetFrame = targetView.convert(targetView.bounds, to: self)
        let inset        = targetFrame.insetBy(dx: -10, dy: -10)
        let hole         = UIBezierPath(roundedRect: inset, cornerRadius: Style.cornerRadius)
        let fullPath     = UIBezierPath(rect: bounds)
        fullPath.append(hole)
        fullPath.usesEvenOddFillRule = true
        maskLayer.fillRule = .evenOdd

        if animated, maskLayer.path != nil {
            let anim            = CABasicAnimation(keyPath: "path")
            anim.fromValue      = maskLayer.path
            anim.toValue        = fullPath.cgPath
            anim.duration       = 0.38
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            maskLayer.add(anim, forKey: "spotlight")
        }
        maskLayer.path = fullPath.cgPath

        // --- Tooltip content ---
        stepBadge.text      = "STEP \(stepIndex + 1) OF \(progressStack.arrangedSubviews.count)"
        tooltipTitle.text   = title
        tooltipMessage.text = message
        updateDots(activeIndex: stepIndex)

        // --- Position tooltip ---
        tooltipTopConstraint?.isActive    = false
        tooltipBottomConstraint?.isActive = false

        if tooltipBelow {
            tooltipTopConstraint = tooltipContainer.topAnchor.constraint(
                equalTo: topAnchor, constant: inset.maxY + 20)
            tooltipTopConstraint?.isActive = true
        } else {
            tooltipBottomConstraint = tooltipContainer.bottomAnchor.constraint(
                equalTo: topAnchor, constant: inset.minY - 20)
            tooltipBottomConstraint?.isActive = true
        }

        // --- Animate tooltip in ---
        tooltipContainer.alpha     = 0
        tooltipContainer.transform = CGAffineTransform(translationX: 0, y: tooltipBelow ? -10 : 10)

        UIView.animate(withDuration: 0.3, delay: 0.2, options: .curveEaseOut) {
            self.tooltipContainer.alpha     = 1
            self.tooltipContainer.transform = .identity
            self.layoutIfNeeded()
        }
    }

    // MARK: - Helpers

    private func makeDot(active: Bool) -> UIView {
        let v    = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        let size: CGFloat = active ? 8 : 6
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: size),
            v.heightAnchor.constraint(equalToConstant: size),
        ])
        v.layer.cornerRadius = size / 2
        v.backgroundColor    = active ? Style.accentGreen : UIColor.lightGray.withAlphaComponent(0.3)
        return v
    }

    private func updateDots(activeIndex: Int) {
        for (i, dot) in progressStack.arrangedSubviews.enumerated() {
            let isActive = i == activeIndex
            UIView.animate(withDuration: 0.25) {
                dot.backgroundColor    = isActive
                    ? Style.accentGreen
                    : UIColor.lightGray.withAlphaComponent(0.3)
                let size: CGFloat      = isActive ? 8 : 6
                dot.layer.cornerRadius = size / 2
                dot.constraints.forEach { c in
                    if c.firstAttribute == .width || c.firstAttribute == .height {
                        c.constant = size
                    }
                }
            }
        }
    }

    @objc private func tapped() { onTap?() }
}
