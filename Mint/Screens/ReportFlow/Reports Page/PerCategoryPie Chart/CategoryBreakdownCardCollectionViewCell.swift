import UIKit

struct CategorySpending {
    let name: String
    let icon: String
    let color: UIColor
    let amount: Double
    let percent: Int
}

class CategoryBreakdownCardCollectionViewCell: UICollectionViewCell {

    private var currentCategories: [CategorySpending] = []
    private let donutLayer = CALayer()

    @IBOutlet weak var PieChartView: UIView!
    @IBOutlet weak var categoriesImageView: UIImageView!
    @IBOutlet weak var CategoriesNameLabel: UILabel!
    @IBOutlet weak var percentLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        PieChartView.layer.insertSublayer(donutLayer, at: 0)
        categoriesImageView.tintColor = AppColors.textPrimary
        CategoriesNameLabel.textColor = AppColors.textPrimary
        percentLabel.textColor = AppColors.textPrimary
    }

    func configure(with categories: [CategorySpending]) {
        currentCategories = categories
        configureCenterContent(with: categories.first)
        drawDonut(categories: categories)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        donutLayer.frame = PieChartView.bounds
        drawDonut(categories: currentCategories)
    }

    private func drawDonut(categories: [CategorySpending]) {
        donutLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

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

            donutLayer.addSublayer(layer)
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

        donutLayer.addSublayer(layer)
    }

    private func configureCenterContent(with category: CategorySpending?) {
        guard let category else {
            categoriesImageView.image = nil
            CategoriesNameLabel.text = nil
            percentLabel.text = nil
            return
        }

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        categoriesImageView.image = UIImage(systemName: category.icon, withConfiguration: symbolConfig)
        categoriesImageView.tintColor = category.color
        CategoriesNameLabel.text = category.name
        CategoriesNameLabel.textColor = category.color
        percentLabel.text = "\(category.percent)%"
        percentLabel.textColor = AppColors.textPrimary
    }
}
