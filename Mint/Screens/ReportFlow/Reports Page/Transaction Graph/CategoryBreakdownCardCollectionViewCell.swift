import UIKit

struct CategorySpending {
    let name: String
    let color: UIColor
    let percent: Int
}

class CategoryBreakdownCardCollectionViewCell: UICollectionViewCell {

    private var currentCategories: [CategorySpending] = []

    @IBOutlet weak var PieChartView: UIView!

    @IBOutlet weak var FirstCategoryView: UIView!
    @IBOutlet weak var FirstCategoryNameLabel: UILabel!
    @IBOutlet weak var FirstCategoryPercentLabel: UILabel!

    @IBOutlet weak var SecondCategoryView: UIView!
    @IBOutlet weak var SecondCategoryNameLabel: UILabel!
    @IBOutlet weak var SecondCategoryPercentLabel: UILabel!

    @IBOutlet weak var ThirdCategoryView: UIView!
    @IBOutlet weak var ThirdCategoryNameLabel: UILabel!
    @IBOutlet weak var ThirdCategoryPercentLabel: UILabel!

    @IBOutlet weak var FourthCategoryView: UIView!
    @IBOutlet weak var FourthCategoryNameLabel: UILabel!
    @IBOutlet weak var FourthCategoryPercentLabel: UILabel!

    func configure(with categories: [CategorySpending]) {
        currentCategories = categories
        setRow(dot: FirstCategoryView,  name: FirstCategoryNameLabel,  percent: FirstCategoryPercentLabel,  cat: categories.count > 0 ? categories[0] : nil)
        setRow(dot: SecondCategoryView, name: SecondCategoryNameLabel, percent: SecondCategoryPercentLabel, cat: categories.count > 1 ? categories[1] : nil)
        setRow(dot: ThirdCategoryView,  name: ThirdCategoryNameLabel,  percent: ThirdCategoryPercentLabel,  cat: categories.count > 2 ? categories[2] : nil)
        setRow(dot: FourthCategoryView, name: FourthCategoryNameLabel, percent: FourthCategoryPercentLabel, cat: categories.count > 3 ? categories[3] : nil)

        drawDonut(categories: categories)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawDonut(categories: currentCategories)
    }

    private func setRow(dot: UIView?, name: UILabel?, percent: UILabel?, cat: CategorySpending?) {
        guard let cat = cat else {
            dot?.superview?.isHidden = true
            return
        }
        dot?.superview?.isHidden = false
        dot?.backgroundColor = cat.color
        name?.text           = cat.name
        name?.textColor      = AppColors.textPrimary
        percent?.text        = "\(cat.percent)%"
        percent?.textColor   = AppColors.textSecondary
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
