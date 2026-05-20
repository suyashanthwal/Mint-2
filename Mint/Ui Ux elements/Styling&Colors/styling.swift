
import UIKit
import CoreText
import ObjectiveC.runtime

extension UIView {
    var allSubviews: [UIView] {
        subviews + subviews.flatMap { $0.allSubviews }
    }

    func applyShadow() {
        self.layer.cornerRadius  = 12.0
        self.layer.shadowColor   = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.05
        self.layer.shadowOffset  = CGSize(width: 0, height: 1)
        self.layer.shadowRadius  = 1
        self.layer.masksToBounds = false
    }
}

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

let currencyFormatter: NumberFormatter = {
    let f            = NumberFormatter()
    f.numberStyle    = .currency
    f.currencyCode   = "INR"
    f.locale         = Locale(identifier: "en_IN")
    return f
}()
extension UIView {
    
    func applyCardIconStyle() {
        self.backgroundColor    = AppColors.brandLight.withAlphaComponent(0.4)
        self.layer.cornerRadius = self.bounds.width / 2
        self.clipsToBounds      = true
    }
}

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

extension UIView {
    func applyPillStyle() {
        self.backgroundColor    = AppColors.sectionBackground
        self.layer.cornerRadius = 14
        self.clipsToBounds      = true
    }
}

extension UIView {

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

    
    func applyCalendarTodayStyle() {
        backgroundColor    = AppColors.brand
        layer.cornerRadius = 12
        clipsToBounds      = true
    }
    
    func applyCalendarEmptyStyle() {
        backgroundColor    = .clear
        layer.cornerRadius = 0
        clipsToBounds      = false
    }

    func applyDotStyle() {
        backgroundColor    = AppColors.brand
        layer.cornerRadius = bounds.height / 2
        clipsToBounds      = true
    }
}

extension NSMutableAttributedString {

    @discardableResult
    func appendBrand(_ text: String, font: UIFont? = nil) -> NSMutableAttributedString {
        var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: AppColors.brand]
        if let f = font { attrs[.font] = f }
        append(NSAttributedString(string: text, attributes: attrs))
        return self
    }

    @discardableResult
    func appendSecondary(_ text: String, font: UIFont? = nil) -> NSMutableAttributedString {
        var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: AppColors.textSecondary]
        if let f = font { attrs[.font] = f }
        append(NSAttributedString(string: text, attributes: attrs))
        return self
    }
}

enum MintFont {
    fileprivate static let weightAxisTag = fourCharacterCode("wght")

    static func space(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        customFont(
            names: weightedNames(
                family: "SpaceGrotesk",
                spacedFamily: "Space Grotesk",
                weight: weight
            ),
            size: size,
            fallbackWeight: weight
        )
    }

    static func syne(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        customFont(
            names: weightedNames(
                family: "Syne",
                spacedFamily: "Syne",
                weight: weight
            ),
            size: size,
            fallbackWeight: weight
        )
    }

    static func space(matching font: UIFont?, fallbackSize: CGFloat = 17) -> UIFont {
        space(
            size: font?.pointSize ?? fallbackSize,
            weight: weight(for: font)
        )
    }

    static func weight(for font: UIFont?) -> UIFont.Weight {
        guard let font else { return .regular }
        if let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any],
           let traitWeight = traits[.weight] as? CGFloat {
            switch traitWeight {
            case ..<(-0.45):
                return .light
            case -0.45..<0.15:
                return .regular
            case 0.15..<0.3:
                return .medium
            case 0.3..<0.5:
                return .semibold
            case 0.5..<0.7:
                return .bold
            default:
                return .heavy
            }
        }

        let traits = font.fontDescriptor.symbolicTraits
        if traits.contains(.traitBold) {
            return .bold
        }
        return .regular
    }

    private static func weightedNames(
        family: String,
        spacedFamily: String,
        weight: UIFont.Weight
    ) -> [String] {
        let suffix: String
        switch weight {
        case .black, .heavy:
            suffix = "ExtraBold"
        case .bold:
            suffix = "Bold"
        case .semibold:
            suffix = "SemiBold"
        case .medium:
            suffix = "Medium"
        default:
            suffix = "Regular"
        }

        return [
            "\(family)-\(suffix)",
            "\(spacedFamily)-\(suffix)",
            "\(family)-VariableFont_wght",
            "\(spacedFamily)-VariableFont_wght",
            "\(family)-Regular",
            "\(spacedFamily)-Regular",
            family,
            spacedFamily
        ]
    }

    private static func fourCharacterCode(_ string: String) -> Int {
        string.unicodeScalars.reduce(0) { partialResult, scalar in
            (partialResult << 8) + Int(scalar.value)
        }
    }

    private static func customFont(
        names: [String],
        size: CGFloat,
        fallbackWeight: UIFont.Weight
    ) -> UIFont {
        for name in names {
            if let font = UIFont(name: name, size: size) {
                return font.withVariableWeight(fallbackWeight) ?? font
            }
        }
        return .systemFont(ofSize: size, weight: fallbackWeight)
    }
}

extension UIView {
    func applyMintTypography() {
        if let label = self as? UILabel {
            label.font = MintFont.space(matching: label.font)
            label.removeCharacterSpacing()
        }

        if let textField = self as? UITextField {
            textField.font = MintFont.space(matching: textField.font)
            textField.applyMintPlaceholderFont()
        }

        if let textView = self as? UITextView {
            textView.font = MintFont.space(matching: textView.font)
        }

        if let button = self as? UIButton {
            button.titleLabel?.font = MintFont.space(matching: button.titleLabel?.font)
        }

        if let segmentedControl = self as? UISegmentedControl {
            let font = MintFont.space(size: 13, weight: .semibold)
            segmentedControl.setTitleTextAttributes([.font: font], for: .normal)
            segmentedControl.setTitleTextAttributes([.font: font], for: .selected)
        }

        if let datePicker = self as? UIDatePicker {
            datePicker.applyMintDatePickerStyle()
        }

        subviews.forEach { $0.applyMintTypography() }
    }

    func applyAddEditInputContainerStyle() {
        backgroundColor = AppColors.inputBackground
        layer.borderColor = AppColors.cardBorder.cgColor
        layer.borderWidth = 1
        applyShadow()
    }

    func applyOnboardingCardStyle(cornerRadius: CGFloat = 22) {
        backgroundColor = AppColors.card
        layer.cornerRadius = cornerRadius
        layer.borderWidth = 1
        layer.borderColor = AppColors.cardBorder.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 10)
        layer.shadowRadius = 24
        layer.masksToBounds = false
    }
}

extension UIViewController {
    static func enableMintTypographySwizzle() {
        struct SwizzleToken {
            static let once: Void = {
                let originalSelector = #selector(UIViewController.viewDidLoad)
                let swizzledSelector = #selector(UIViewController.mint_viewDidLoad)

                guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
                      let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
                    return
                }

                method_exchangeImplementations(originalMethod, swizzledMethod)
            }()
        }

        _ = SwizzleToken.once
    }

    @objc private func mint_viewDidLoad() {
        mint_viewDidLoad()
        view.applyMintTypography()
    }
}

extension UISegmentedControl {
    func applyAddEditSegmentStyle() {
        backgroundColor = AppColors.sectionBackground
        selectedSegmentTintColor = AppColors.inputBackground
        tintColor = AppColors.brand

        setTitleTextAttributes(
            [
                .foregroundColor: AppColors.textSecondary,
                .font: MintFont.space(size: 14, weight: .semibold),
                .kern: 0
            ],
            for: .normal
        )
        setTitleTextAttributes(
            [
                .foregroundColor: AppColors.textPrimary,
                .font: MintFont.space(size: 14, weight: .bold),
                .kern: 0
            ],
            for: .selected
        )
    }
}

extension UIDatePicker {
    func applyMintDatePickerStyle() {
        tintColor = AppColors.brand
        backgroundColor = .clear
        overrideUserInterfaceStyle = .dark
        applyDatePickerTextColor()

        DispatchQueue.main.async { [weak self] in
            self?.applyDatePickerTextColor()
        }
    }

    private func applyDatePickerTextColor() {
        updateDatePickerTextColor(in: self)
    }

    private func updateDatePickerTextColor(in view: UIView) {
        if let label = view as? UILabel {
            label.textColor = AppColors.textPrimary
        }

        view.subviews.forEach { updateDatePickerTextColor(in: $0) }
    }
}

extension UITextField {
    func applyAddEditInputStyle(keyboardType: UIKeyboardType? = nil) {
        backgroundColor = AppColors.inputBackground
        textColor = AppColors.textPrimary
        tintColor = AppColors.brand
        font = MintFont.space(matching: font)
        if let keyboardType {
            self.keyboardType = keyboardType
        }
        applyMintPlaceholderFont()
    }

    func applyMintPlaceholderFont(placeholder: String? = nil) {
        let placeholderText = placeholder ?? self.placeholder ?? attributedPlaceholder?.string
        guard let placeholderText else { return }
        attributedPlaceholder = NSAttributedString(
            string: placeholderText,
            attributes: [
                .foregroundColor: AppColors.textSecondary,
                .font: font as Any
            ]
        )
    }
}

extension UIButton {
    func applyPrimaryOnboardingStyle() {
        var config = configuration ?? .filled()
        config.baseBackgroundColor = AppColors.accent
        config.baseForegroundColor = AppColors.brandText
        config.cornerStyle = .large
        config.background.backgroundColor = AppColors.accent
        config.background.strokeColor = AppColors.brand
        config.background.strokeWidth = 0
        configuration = config
        tintColor = AppColors.brandText
        backgroundColor = .clear
        layer.borderWidth = 0
        layer.borderColor = UIColor.clear.cgColor
        titleLabel?.font = MintFont.space(size: 17, weight: .bold)
    }

    func applySecondaryOnboardingStyle() {
        var config = configuration ?? .plain()
        config.baseBackgroundColor = .clear
        config.baseForegroundColor = AppColors.textSecondary
        configuration = config
        tintColor = AppColors.textSecondary
        titleLabel?.font = MintFont.space(size: 15, weight: .semibold)
    }
}

extension UILabel {
    func removeCharacterSpacing() {
        guard let text else { return }
        attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font as Any,
                .foregroundColor: textColor as Any,
                .kern: 0
            ]
        )
    }
}

private extension UIFont {
    func withVariableWeight(_ weight: UIFont.Weight) -> UIFont? {
        let targetValue = weight.variableAxisValue
        let ctFont = self as CTFont
        guard let axes = CTFontCopyVariationAxes(ctFont) as? [[CFString: Any]] else {
            return nil
        }

        let weightAxisTag = MintFont.weightAxisTag
        guard let weightAxis = axes.first(where: { axis in
            (axis[kCTFontVariationAxisIdentifierKey] as? NSNumber)?.intValue == weightAxisTag
        }) else {
            return nil
        }

        let minValue = (weightAxis[kCTFontVariationAxisMinimumValueKey] as? NSNumber)?.doubleValue ?? targetValue
        let maxValue = (weightAxis[kCTFontVariationAxisMaximumValueKey] as? NSNumber)?.doubleValue ?? targetValue
        let clampedValue = min(max(targetValue, minValue), maxValue)

        let variationKey = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = fontDescriptor.addingAttributes([
            variationKey: [weightAxisTag: clampedValue]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

private extension UIFont.Weight {
    var variableAxisValue: Double {
        switch self {
        case .ultraLight:
            return 200
        case .thin:
            return 250
        case .light:
            return 300
        case .regular:
            return 400
        case .medium:
            return 500
        case .semibold:
            return 600
        case .bold:
            return 700
        case .heavy:
            return 800
        case .black:
            return 900
        default:
            return 400
        }
    }
}
