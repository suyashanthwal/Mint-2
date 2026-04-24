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

        guard !categories.isEmpty else { return }

        let center = CGPoint(x: PieChartView.bounds.midX, y: PieChartView.bounds.midY)
        let radius: CGFloat = min(PieChartView.bounds.width, PieChartView.bounds.height) / 2 - 8
        let total = categories.reduce(0) { $0 + $1.percent }
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
}
