import UIKit

struct CategorySpending {
    let name: String
    let color: UIColor
    let amount: Double
    let percent: Int
}

class CategoryBreakdownCardCollectionViewCell: UICollectionViewCell {

    private var currentCategories: [CategorySpending] = []

    @IBOutlet weak var PieChartView: UIView!

    func configure(with categories: [CategorySpending]) {
        currentCategories = categories
        drawDonut(categories: categories)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawDonut(categories: currentCategories)
    }

    private func drawDonut(categories: [CategorySpending]) {
        PieChartView.layer.sublayers?.removeAll()

        let center = CGPoint(x: PieChartView.bounds.midX, y: PieChartView.bounds.midY)
        let radius: CGFloat = min(PieChartView.bounds.width, PieChartView.bounds.height) / 2 - 8
        guard radius > 0 else { return }

        guard !categories.isEmpty else {
            drawEmptyDonut(center: center, radius: radius)
            return
        }

        let total = categories.reduce(0) { $0 + $1.percent }
        guard total > 0 else {
            drawEmptyDonut(center: center, radius: radius)
            return
        }
        var startAngle: CGFloat = -.pi / 2

        for cat in categories {
            let sweep = CGFloat(cat.percent) / CGFloat(total) * 2 * .pi
            let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: startAngle + sweep - 0.05, clockwise: true)

            let layer = CAShapeLayer()
            layer.path        = path.cgPath
            layer.strokeColor = cat.color.cgColor
            layer.fillColor   = UIColor.clear.cgColor
            layer.lineWidth   = 20

            PieChartView.layer.addSublayer(layer)
            startAngle += sweep
        }
    }

    private func drawEmptyDonut(center: CGPoint, radius: CGFloat) {
        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: -.pi / 2 + 2 * .pi,
            clockwise: true
        )

        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.strokeColor = AppColors.inputBackground.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 20

        PieChartView.layer.addSublayer(layer)
    }
}
