
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
