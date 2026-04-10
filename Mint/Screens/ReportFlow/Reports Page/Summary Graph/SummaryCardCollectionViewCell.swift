import UIKit

struct DailySpending {
    let day: Int
    let amount: Double
}

final class SummaryCardCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var AverageDailyLimitHeadingLabel: UILabel!
    @IBOutlet weak var AverageDailyLimitAmountLabel: UILabel!
    @IBOutlet weak var VsLastMonthLabel: UILabel!
    @IBOutlet weak var VsLastMonthView: UIView!
    @IBOutlet weak var LineGraphView: UIView!

    private let graphLayer = CALayer()
    private let tooltipView = UIView()
    private let tooltipLabel = UILabel()
    private var currentData: [DailySpending] = []
    private var currentAverageOverride: Double?
    private var previousMonthAverage: Double?
    private var lastDrawnBounds: CGRect = .zero
    private var plottedPoints: [CGPoint] = []
    private var plottedPadding = UIEdgeInsets(top: 24, left: 44, bottom: 38, right: 16)

    override func awakeFromNib() {
        super.awakeFromNib()
        AverageDailyLimitHeadingLabel.textColor = AppColors.textPrimary
        AverageDailyLimitAmountLabel.textColor = AppColors.brand
        VsLastMonthView.backgroundColor = AppColors.brandLight
        VsLastMonthLabel.textColor = AppColors.brandLightText
        LineGraphView.layer.addSublayer(graphLayer)
        setupTooltip()
        setupGestures()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentData = []
        currentAverageOverride = nil
        previousMonthAverage = nil
        plottedPoints = []
        lastDrawnBounds = .zero
        clearGraph()
        hideTooltip()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        graphLayer.frame = LineGraphView.bounds

        guard LineGraphView.bounds.width > 0, LineGraphView.bounds.height > 0 else { return }
        let graphIsEmpty = graphLayer.sublayers.orEmpty.isEmpty && LineGraphView.subviews.isEmpty
        guard lastDrawnBounds != LineGraphView.bounds || graphIsEmpty else { return }

        lastDrawnBounds = LineGraphView.bounds
        drawGraph()
    }

    func configure(with data: [DailySpending], currentAverage: Double?, previousMonthAverage: Double?) {
        currentData = data.sorted { $0.day < $1.day }
        currentAverageOverride = currentAverage
        self.previousMonthAverage = previousMonthAverage
        applySummaryLabels()
        lastDrawnBounds = .zero
        setNeedsLayout()
        if LineGraphView.bounds.width > 0, LineGraphView.bounds.height > 0 {
            layoutIfNeeded()
        }
    }

    private func clearGraph() {
        graphLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        LineGraphView.subviews.filter { $0 !== tooltipView }.forEach { $0.removeFromSuperview() }
    }

    private func drawGraph() {
        clearGraph()

        guard currentData.count > 1 else { return }

        let bounds = LineGraphView.bounds
        let width = bounds.width
        let height = bounds.height
        let padding = UIEdgeInsets(top: 24, left: 44, bottom: 38, right: 16)
        let graphWidth = width - padding.left - padding.right
        let graphHeight = height - padding.top - padding.bottom

        guard graphWidth > 0, graphHeight > 0 else { return }

        let amounts = currentData.map(\.amount)
        let maxAmount = max(amounts.max() ?? 0, 1)
        let minAmount = 0.0
        let valueRange = max(maxAmount - minAmount, 1)
        let graphAverage = amounts.reduce(0, +) / Double(amounts.count)
        let summaryAverage = currentAverageOverride ?? graphAverage

        applySummaryLabels(average: summaryAverage)
        plottedPadding = padding

        func point(at index: Int) -> CGPoint {
            let xProgress = CGFloat(index) / CGFloat(max(currentData.count - 1, 1))
            let yProgress = CGFloat((amounts[index] - minAmount) / valueRange)
            return CGPoint(
                x: padding.left + (graphWidth * xProgress),
                y: padding.top + graphHeight - (graphHeight * yProgress)
            )
        }

        plottedPoints = currentData.indices.map(point)

        addGrid(width: width, graphHeight: graphHeight, padding: padding, maxAmount: maxAmount)
        addSpendingLine(using: point)
        addAverageLine(width: width, graphHeight: graphHeight, padding: padding, average: summaryAverage, maxAmount: maxAmount)
        addDots(using: point)
        addXAxisLabels(height: height, padding: padding, pointProvider: point)
        addAverageLabel(width: width, graphHeight: graphHeight, padding: padding, average: summaryAverage, maxAmount: maxAmount)
        updateTooltip(at: plottedPoints.last)
    }

    private func addGrid(width: CGFloat, graphHeight: CGFloat, padding: UIEdgeInsets, maxAmount: Double) {
        let steps = 4

        for step in 0...steps {
            let ratio = CGFloat(step) / CGFloat(steps)
            let y = padding.top + graphHeight - (graphHeight * ratio)

            let path = UIBezierPath()
            path.move(to: CGPoint(x: padding.left, y: y))
            path.addLine(to: CGPoint(x: width - padding.right, y: y))

            let lineLayer = CAShapeLayer()
            lineLayer.path = path.cgPath
            lineLayer.strokeColor = AppColors.textSecondary.withAlphaComponent(0.14).cgColor
            lineLayer.lineWidth = 1
            graphLayer.addSublayer(lineLayer)

            let value = (maxAmount / Double(steps)) * Double(step)
            let label = UILabel()
            label.font = .systemFont(ofSize: 9, weight: .medium)
            label.textColor = AppColors.textSecondary
            label.text = formattedCurrency(value)
            label.sizeToFit()
            label.frame.origin = CGPoint(x: 4, y: y - (label.bounds.height / 2))
            LineGraphView.addSubview(label)
        }
    }

    private func addAverageLine(width: CGFloat, graphHeight: CGFloat, padding: UIEdgeInsets, average: Double, maxAmount: Double) {
        let averageY = yPosition(for: average, graphHeight: graphHeight, padding: padding, maxAmount: maxAmount)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: padding.left, y: averageY))
        path.addLine(to: CGPoint(x: width - padding.right, y: averageY))

        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.strokeColor = AppColors.textPrimary.withAlphaComponent(0.35).cgColor
        layer.lineWidth = 1.5
        layer.lineDashPattern = [6, 5]
        graphLayer.addSublayer(layer)
    }

    private func addSpendingLine(using pointProvider: (Int) -> CGPoint) {
        let path = UIBezierPath()
        path.move(to: pointProvider(0))

        for index in 1..<currentData.count {
            let previous = pointProvider(index - 1)
            let current = pointProvider(index)
            let midX = (previous.x + current.x) / 2

            path.addCurve(
                to: current,
                controlPoint1: CGPoint(x: midX, y: previous.y),
                controlPoint2: CGPoint(x: midX, y: current.y)
            )
        }

        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.strokeColor = AppColors.error.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 3
        layer.lineCap = .round
        layer.lineJoin = .round
        graphLayer.addSublayer(layer)
    }

    private func addDots(using pointProvider: (Int) -> CGPoint) {
        for index in currentData.indices {
            let center = pointProvider(index)

            let outerCircle = CAShapeLayer()
            outerCircle.path = UIBezierPath(
                arcCenter: center,
                radius: 4.5,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            ).cgPath
            outerCircle.fillColor = AppColors.card.cgColor
            graphLayer.addSublayer(outerCircle)

            let innerCircle = CAShapeLayer()
            innerCircle.path = UIBezierPath(
                arcCenter: center,
                radius: 3,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            ).cgPath
            innerCircle.fillColor = AppColors.error.cgColor
            graphLayer.addSublayer(innerCircle)
        }
    }

    private func addXAxisLabels(height: CGFloat, padding: UIEdgeInsets, pointProvider: (Int) -> CGPoint) {
        for (index, item) in currentData.enumerated() {
            let label = UILabel()
            label.font = .systemFont(ofSize: 9, weight: .medium)
            label.textColor = AppColors.textSecondary
            label.text = "\(item.day)"
            label.sizeToFit()
            label.center = CGPoint(x: pointProvider(index).x, y: height - (padding.bottom / 2))
            LineGraphView.addSubview(label)
        }
    }

    private func addAverageLabel(width: CGFloat, graphHeight: CGFloat, padding: UIEdgeInsets, average: Double, maxAmount: Double) {
        let averageY = yPosition(for: average, graphHeight: graphHeight, padding: padding, maxAmount: maxAmount)

        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = AppColors.textSecondary
        label.text = "Daily avg \(formattedCurrency(average))"
        label.sizeToFit()

        let containerPadding = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        let containerSize = CGSize(
            width: label.bounds.width + containerPadding.left + containerPadding.right,
            height: label.bounds.height + containerPadding.top + containerPadding.bottom
        )
        let container = UIView(frame: CGRect(origin: .zero, size: containerSize))
        container.backgroundColor = AppColors.card.withAlphaComponent(0.96)
        container.layer.cornerRadius = containerSize.height / 2

        let preferredY = averageY - containerSize.height - 6
        let adjustedY = max(2, min(preferredY, graphHeight + padding.top - containerSize.height))
        container.frame.origin = CGPoint(
            x: width - padding.right - containerSize.width,
            y: adjustedY
        )

        label.frame.origin = CGPoint(x: containerPadding.left, y: containerPadding.top)
        container.addSubview(label)
        LineGraphView.addSubview(container)
    }

    private func applySummaryLabels(average: Double? = nil) {
        let resolvedAverage = average ?? currentAverage
        AverageDailyLimitAmountLabel.text = formattedAmount(resolvedAverage)

        guard let previousMonthAverage, previousMonthAverage > 0, let resolvedAverage else {
            VsLastMonthLabel.text = "No last month data"
            return
        }

        let change = ((resolvedAverage - previousMonthAverage) / previousMonthAverage) * 100
        let roundedPercent = Int(change.rounded())
        let prefix = roundedPercent > 0 ? "+" : ""
        VsLastMonthLabel.text = "\(prefix)\(roundedPercent)% vs last month"
    }

    private var currentAverage: Double? {
        if let currentAverageOverride {
            return currentAverageOverride
        }

        guard !currentData.isEmpty else { return nil }
        return currentData.map(\.amount).reduce(0, +) / Double(currentData.count)
    }

    private func yPosition(for value: Double, graphHeight: CGFloat, padding: UIEdgeInsets, maxAmount: Double) -> CGFloat {
        let valueRange = max(maxAmount, 1)
        let ratio = CGFloat(value / valueRange)
        return padding.top + graphHeight - (graphHeight * ratio)
    }

    private func formattedAmount(_ amount: Double?) -> String {
        guard let amount else { return "₹0.00" }
        return String(format: "₹%.2f", amount)
    }

    private func formattedCurrency(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "₹%.1fk", amount / 1000)
        }
        return String(format: "₹%.0f", amount)
    }

    private func setupTooltip() {
        tooltipView.backgroundColor = AppColors.brand
        tooltipView.layer.cornerRadius = 12
        tooltipView.clipsToBounds = true
        tooltipView.isHidden = true

        tooltipLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        tooltipLabel.textColor = AppColors.brandText
        tooltipView.addSubview(tooltipLabel)
        LineGraphView.addSubview(tooltipView)
    }

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleGraphTouch(_:)))
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleGraphPan(_:)))
        LineGraphView.addGestureRecognizer(tapGesture)
        LineGraphView.addGestureRecognizer(panGesture)
    }

    @objc
    private func handleGraphTouch(_ gesture: UITapGestureRecognizer) {
        updateTooltip(at: nearestPoint(to: gesture.location(in: LineGraphView)))
    }

    @objc
    private func handleGraphPan(_ gesture: UIPanGestureRecognizer) {
        updateTooltip(at: nearestPoint(to: gesture.location(in: LineGraphView)))
    }

    private func nearestPoint(to location: CGPoint) -> CGPoint? {
        guard !plottedPoints.isEmpty else { return nil }
        let clampedX = max(plottedPadding.left, min(location.x, LineGraphView.bounds.width - plottedPadding.right))
        return plottedPoints.min { abs($0.x - clampedX) < abs($1.x - clampedX) }
    }

    private func updateTooltip(at point: CGPoint?) {
        guard let point,
              let index = plottedPoints.firstIndex(where: { abs($0.x - point.x) < 0.5 && abs($0.y - point.y) < 0.5 }),
              currentData.indices.contains(index) else {
            hideTooltip()
            return
        }

        let item = currentData[index]
        tooltipLabel.text = "\(item.day) • \(formattedCurrency(item.amount))"
        tooltipLabel.sizeToFit()

        let horizontalPadding: CGFloat = 8
        let verticalPadding: CGFloat = 5
        let width = tooltipLabel.bounds.width + horizontalPadding * 2
        let height = tooltipLabel.bounds.height + verticalPadding * 2

        tooltipView.frame.size = CGSize(width: width, height: height)
        tooltipView.layer.cornerRadius = height / 2
        tooltipLabel.frame.origin = CGPoint(x: horizontalPadding, y: verticalPadding)

        let targetX = min(max(point.x - width / 2, 4), LineGraphView.bounds.width - width - 4)
        let preferredY = point.y - height - 10
        let fallbackY = point.y + 10
        tooltipView.frame.origin = CGPoint(x: targetX, y: preferredY > 0 ? preferredY : fallbackY)
        tooltipView.isHidden = false
        LineGraphView.bringSubviewToFront(tooltipView)
    }

    private func hideTooltip() {
        tooltipView.isHidden = true
    }
}

private extension Optional where Wrapped == [CALayer] {
    var orEmpty: [CALayer] { self ?? [] }
}
