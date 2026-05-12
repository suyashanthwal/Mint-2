import UIKit

@IBDesignable
final class ScannerBoxView: UIView {

    private let topLeftCorner = CAShapeLayer()
    private let topRightCorner = CAShapeLayer()
    private let bottomLeftCorner = CAShapeLayer()
    private let bottomRightCorner = CAShapeLayer()

    private let cornerLength: CGFloat = 24
    private let cornerLineWidth: CGFloat = 4
    private let cRadius: CGFloat = 16

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCornerLayers()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCornerLayers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCorners()
    }

    private func setupCornerLayers() {
        layer.cornerRadius = cRadius
        clipsToBounds = false

        for cornerLayer in [topLeftCorner, topRightCorner, bottomLeftCorner, bottomRightCorner] {
            cornerLayer.strokeColor = AppColors.brand.cgColor
            cornerLayer.fillColor = UIColor.clear.cgColor
            cornerLayer.lineWidth = cornerLineWidth
            cornerLayer.lineCap = .round
            layer.addSublayer(cornerLayer)
        }
    }

    func updateCorners() {
        let b = bounds
        let cl = cornerLength
        let cr = cRadius

        let tlPath = UIBezierPath()
        tlPath.move(to: CGPoint(x: 0, y: cl + cr))
        tlPath.addLine(to: CGPoint(x: 0, y: cr))
        tlPath.addQuadCurve(to: CGPoint(x: cr, y: 0), controlPoint: .zero)
        tlPath.addLine(to: CGPoint(x: cl + cr, y: 0))
        topLeftCorner.path = tlPath.cgPath

        let trPath = UIBezierPath()
        trPath.move(to: CGPoint(x: b.maxX - cl - cr, y: 0))
        trPath.addLine(to: CGPoint(x: b.maxX - cr, y: 0))
        trPath.addQuadCurve(to: CGPoint(x: b.maxX, y: cr),
                            controlPoint: CGPoint(x: b.maxX, y: 0))
        trPath.addLine(to: CGPoint(x: b.maxX, y: cl + cr))
        topRightCorner.path = trPath.cgPath

        let blPath = UIBezierPath()
        blPath.move(to: CGPoint(x: 0, y: b.maxY - cl - cr))
        blPath.addLine(to: CGPoint(x: 0, y: b.maxY - cr))
        blPath.addQuadCurve(to: CGPoint(x: cr, y: b.maxY),
                            controlPoint: CGPoint(x: 0, y: b.maxY))
        blPath.addLine(to: CGPoint(x: cl + cr, y: b.maxY))
        bottomLeftCorner.path = blPath.cgPath

        let brPath = UIBezierPath()
        brPath.move(to: CGPoint(x: b.maxX - cl - cr, y: b.maxY))
        brPath.addLine(to: CGPoint(x: b.maxX - cr, y: b.maxY))
        brPath.addQuadCurve(to: CGPoint(x: b.maxX, y: b.maxY - cr),
                            controlPoint: CGPoint(x: b.maxX, y: b.maxY))
        brPath.addLine(to: CGPoint(x: b.maxX, y: b.maxY - cl - cr))
        bottomRightCorner.path = brPath.cgPath
    }
}
