
import UIKit
import DGCharts

class SummaryViewController: UIViewController {

    private final class SummaryAxisValueFormatter: AxisValueFormatter {
        func stringForValue(_ value: Double, axis: AxisBase?) -> String {
            if value >= 1000 {
                return String(format: "₹%.1fk", value / 1000)
            }
            return String(format: "₹%.0f", value)
        }
    }

    private enum EmptyStateMessage {
        static let today = "No transactions recorded today yet."
        static let day = "No transactions recorded for this day."
        static let week = "No transactions recorded for this week."
        static let month = "No transactions recorded for this month."
        static let year = "No transactions recorded for this year."
    }

    @IBOutlet weak var AverageHeadingLabel: UILabel!
    @IBOutlet weak var AmountLabel: UILabel!
    @IBOutlet weak var UPorDOWNPercentLabel: UILabel!
    @IBOutlet weak var detailsHeadingLabel: UILabel!

    @IBOutlet weak var barChartView: BarChartView!
    @IBOutlet weak var monthlyDetailsCollectionView: UICollectionView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var previousPeriodButton: UIButton!
    @IBOutlet weak var nextPeriodButton: UIButton!
    @IBOutlet weak var currentPeriodLabel: UILabel!
    @IBOutlet weak var detailsSectionHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!

    private struct SummaryBucket {
        let label: String
        let expense: Double
        let budget: Double
        let startDate: Date?
        let endDate: Date?
        let transactionId: UUID?
    }

    private struct SummaryDetailItem {
        let title: String
        let amount: Double
    }

    private let db = DatabaseManager.shared

    private var transactions: [Transaction] = []
    private var currentBudget: Budget?
    private var currentBuckets: [SummaryBucket] = []
    private var currentDetails: [SummaryDetailItem] = []
    private var currentAverageAmount: Double = 0
    private var currentComparisonPercent: Double?
    private var currentBudgetLimit: Double = 0
    private var currentRange: TimeRange = .daily
    private var selectedAnchorDate = Date()
    private let yAxisValueFormatter = SummaryAxisValueFormatter()
    private var isShowingPlaceholder: Bool {
        currentDetails.isEmpty
    }

    private var expenseTransactions: [Transaction] {
        transactions
            .filter { $0.type == .expense }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var calendar: Calendar {
        Calendar.current
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupSummaryUI()
        setupChartAppearance()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSummaryDataChange),
            name: .transactionDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSummaryDataChange),
            name: .budgetDataDidChange,
            object: nil
        )
        segmentedControl.selectedSegmentIndex = TimeRange.daily.rawValue
        selectedAnchorDate = Date()
        reloadFromDatabase(animateChart: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
        applyReportNavigationTheme()
        reloadFromDatabase(animateChart: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollInsets()
        updateDetailsSectionHeight()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupSummaryUI() {
        applyReportBackgroundTheme(to: view)
        view.backgroundColor = AppColors.background
        view.tintColor = AppColors.brand

        segmentedControl.backgroundColor = AppColors.sectionBackground
        segmentedControl.selectedSegmentTintColor = AppColors.brand
        segmentedControl.setTitleTextAttributes(
            [
                .foregroundColor: AppColors.textSecondary,
                .font: MintFont.space(size: 13, weight: .medium)
            ],
            for: .normal
        )
        segmentedControl.setTitleTextAttributes(
            [
                .foregroundColor: AppColors.brandText,
                .font: MintFont.space(size: 13, weight: .semibold)
            ],
            for: .selected
        )

        AverageHeadingLabel.textColor = AppColors.textSecondary
        AmountLabel.textColor = AppColors.brand
        UPorDOWNPercentLabel.textColor = AppColors.textSecondary
        currentPeriodLabel.textColor = AppColors.textPrimary
        detailsHeadingLabel.textColor = AppColors.textPrimary
        monthlyDetailsCollectionView.backgroundColor = .clear
        scrollView.backgroundColor = AppColors.background

        [previousPeriodButton, nextPeriodButton].forEach { button in
            button?.backgroundColor = AppColors.card
            button?.tintColor = AppColors.brand
            button?.layer.cornerRadius = 16
            button?.layer.borderWidth = 1
            button?.layer.borderColor = AppColors.cardBorder.withAlphaComponent(0.7).cgColor
        }
    }

    private func applyReportBackgroundTheme(to parent: UIView) {
        switch parent {
        case is UIStackView:
            parent.backgroundColor = .clear
        case is UILabel, is UIButton, is UISegmentedControl:
            parent.backgroundColor = .clear
            return
        case is UICollectionView:
            parent.backgroundColor = .clear
        case is UIScrollView:
            parent.backgroundColor = AppColors.background
        default:
            parent.backgroundColor = AppColors.background
        }

        parent.subviews.forEach { applyReportBackgroundTheme(to: $0) }
    }

    private func applyReportNavigationTheme() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppColors.background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: AppColors.textPrimary,
            .font: MintFont.space(size: 28, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: AppColors.textPrimary,
            .font: MintFont.space(size: 34, weight: .bold)
        ]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColors.textPrimary
    }

    private func setupChartAppearance() {
        barChartView.rightAxis.enabled = false
        barChartView.legend.enabled = false
        barChartView.chartDescription.enabled = false
        barChartView.doubleTapToZoomEnabled = false
        barChartView.pinchZoomEnabled = false
        barChartView.scaleXEnabled = false
        barChartView.scaleYEnabled = false
        barChartView.drawBordersEnabled = false
        barChartView.backgroundColor = AppColors.card
        barChartView.extraTopOffset = 16
        barChartView.extraBottomOffset = 5
        barChartView.extraRightOffset = 10
        barChartView.extraLeftOffset = 6
        barChartView.fitBars = true
        barChartView.delegate = self
        barChartView.noDataText = ""
    }

    private func reloadFromDatabase(animateChart: Bool) {
        transactions = db.fetchTransactions()
        currentBudget = db.fetchCurrentBudget()

        let timeRange = TimeRange(rawValue: segmentedControl.selectedSegmentIndex) ?? .daily
        selectedAnchorDate = clampedAnchorDate(selectedAnchorDate, for: timeRange)
        updateChartData(for: timeRange, animateChart: animateChart)
    }

    @objc private func handleSummaryDataChange() {
        reloadFromDatabase(animateChart: false)
    }

    @IBAction
    func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        guard let timeRange = TimeRange(rawValue: sender.selectedSegmentIndex) else { return }
        selectedAnchorDate = clampedAnchorDate(selectedAnchorDate, for: timeRange)
        updateChartData(for: timeRange, animateChart: true)
    }

    @IBAction private func previousPeriodButtonTapped(_ sender: UIButton) {
        selectedAnchorDate = shiftedAnchorDate(from: selectedAnchorDate, for: currentRange, offset: -1)
        updateChartData(for: currentRange, animateChart: true)
    }

    @IBAction private func nextPeriodButtonTapped(_ sender: UIButton) {
        guard canNavigateForward else { return }
        selectedAnchorDate = shiftedAnchorDate(from: selectedAnchorDate, for: currentRange, offset: 1)
        selectedAnchorDate = clampedAnchorDate(selectedAnchorDate, for: currentRange)
        updateChartData(for: currentRange, animateChart: true)
    }

    private func updateChartData(for timeRange: TimeRange, animateChart: Bool) {
        currentRange = timeRange

        switch timeRange {
        case .daily:
            currentBuckets = makeDailyBuckets()
            currentDetails = makeDailyDetails()
        case .weekly:
            currentBuckets = makeWeeklyBuckets()
            currentDetails = makeWeeklyDetails()
        case .monthly:
            currentBuckets = makeMonthlyBuckets()
            currentDetails = makeMonthlyDetails()
        case .yearly:
            currentBuckets = makeYearlyBuckets()
            currentDetails = makeYearlyDetails()
        }
        currentBudgetLimit = budgetLimit(for: timeRange)
        currentAverageAmount = averageAmount(for: timeRange, buckets: currentBuckets)
        currentComparisonPercent = comparisonPercent(for: timeRange)

        updatePeriodNavigationUI()
        updateTopLabels(for: timeRange)
        updateDetailsHeading(for: timeRange)
        setupChart(labels: currentBuckets.map(\.label), barWidth: timeRange == .monthly ? 0.55 : 0.5, animate: animateChart)
        barChartView.highlightValue(nil)
        monthlyDetailsCollectionView.reloadData()
        DispatchQueue.main.async { self.updateDetailsSectionHeight() }
    }

    private func updateTopLabels(for timeRange: TimeRange) {
        let periodName: String
        switch timeRange {
        case .daily: periodName = "DAILY"
        case .weekly: periodName = "WEEKLY"
        case .monthly: periodName = "MONTHLY"
        case .yearly: periodName = "YEARLY"
        }

        AverageHeadingLabel.text = "AVERAGE \(periodName) SPEND"
        AmountLabel.text = currencyString(currentAverageAmount)

        guard let currentComparisonPercent else {
            UPorDOWNPercentLabel.text = "No previous period data"
            UPorDOWNPercentLabel.textColor = AppColors.textSecondary
            return
        }

        let directionArrow = currentComparisonPercent >= 0 ? "↑" : "↓"
        let color = currentComparisonPercent >= 0 ? AppColors.error : AppColors.brand
        let absPercent = abs(currentComparisonPercent.rounded())

        let text = NSMutableAttributedString(
            string: "\(directionArrow) \(Int(absPercent))%",
            attributes: [
                .foregroundColor: color,
                .font: MintFont.space(size: 16, weight: .semibold)
            ]
        )
        text.append(NSAttributedString(
            string: " vs last period",
            attributes: [
                .foregroundColor: AppColors.textSecondary,
                .font: MintFont.space(size: 16, weight: .regular)
            ]
        ))
        UPorDOWNPercentLabel.attributedText = text
    }

    private func updateDetailsHeading(for timeRange: TimeRange, selectedBucket: SummaryBucket? = nil) {
        if let selectedBucket {
            switch timeRange {
            case .daily:
                detailsHeadingLabel.text = "\(selectedBucket.label) Transactions"
            case .weekly:
                detailsHeadingLabel.text = "\(selectedBucket.label) Transactions"
            case .monthly:
                detailsHeadingLabel.text = "Day \(selectedBucket.label) Transactions"
            case .yearly:
                detailsHeadingLabel.text = "\(selectedBucket.label) Transactions"
            }
        } else {
            switch timeRange {
            case .daily:
                detailsHeadingLabel.text = isCurrentPeriod(for: .daily)
                    ? "Today's Transactions"
                    : "\(dayTitleFormatter.string(from: selectedAnchorDate)) Transactions"
            case .weekly:
                detailsHeadingLabel.text = "\(currentPeriodLabel.text ?? "Weekly") Breakdown"
            case .monthly:
                detailsHeadingLabel.text = "\(currentPeriodLabel.text ?? "Monthly") Breakdown"
            case .yearly:
                detailsHeadingLabel.text = "\(currentPeriodLabel.text ?? "Yearly") Breakdown"
            }
        }
    }

    private func setupChart(labels: [String], barWidth: Double, animate: Bool) {
        let isPlaceholderChart = currentBuckets.isEmpty
        let chartLabels = isPlaceholderChart ? placeholderLabels(for: currentRange) : labels
        let chartValues = isPlaceholderChart ? Array(repeating: 0.0, count: chartLabels.count) : currentBuckets.map(\.expense)

        let entries = chartValues.enumerated().map {
            BarChartDataEntry(x: Double($0.offset), y: $0.element)
        }

        let colors: [NSUIColor] = isPlaceholderChart
            ? Array(repeating: UIColor.clear, count: chartValues.count)
            : currentBuckets.map { bucket in
            if bucket.expense == 0 {
                return AppColors.brandLight
            } else if bucket.budget > 0, bucket.expense > bucket.budget {
                return AppColors.error
            } else {
                return AppColors.brand
            }
        }

        let dataSet = BarChartDataSet(entries: entries, label: "Expense")
        dataSet.colors = colors
        dataSet.drawValuesEnabled = false
        dataSet.highlightEnabled = !isPlaceholderChart

        let data = BarChartData(dataSet: dataSet)
        data.barWidth = barWidth
        barChartView.data = data
        barChartView.highlightPerTapEnabled = !isPlaceholderChart

        let xAxis = barChartView.xAxis
        xAxis.valueFormatter = IndexAxisValueFormatter(values: chartLabels)
        xAxis.granularity = 1
        xAxis.centerAxisLabelsEnabled = false
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        xAxis.labelFont = MintFont.space(size: currentRange == .monthly ? 8 : 9, weight: .medium)
        xAxis.labelTextColor = AppColors.textSecondary
        xAxis.drawAxisLineEnabled = true
        xAxis.axisLineColor = AppColors.textSecondary.withAlphaComponent(0.45)
        xAxis.axisMinimum = -0.5
        xAxis.axisMaximum = Double(max(chartLabels.count, 1)) - 0.5

        let maxExpense = chartAxisMaximum(for: chartValues, isPlaceholder: isPlaceholderChart)
        let leftAxis = barChartView.leftAxis
        leftAxis.axisMinimum = 0
        leftAxis.axisMaximum = maxExpense
        leftAxis.drawGridLinesEnabled = true
        leftAxis.labelFont = MintFont.space(size: 9)
        leftAxis.gridColor = AppColors.textSecondary.withAlphaComponent(0.14)
        leftAxis.gridLineWidth = 1
        leftAxis.labelTextColor = AppColors.textSecondary
        leftAxis.drawAxisLineEnabled = true
        leftAxis.axisLineColor = AppColors.textSecondary.withAlphaComponent(0.45)
        leftAxis.axisLineWidth = 1
        leftAxis.setLabelCount(5, force: true)
        leftAxis.valueFormatter = yAxisValueFormatter
        leftAxis.removeAllLimitLines()

        if !isPlaceholderChart, currentAverageAmount > 0 {
            let averageLine = ChartLimitLine(limit: currentAverageAmount, label: averageLimitLabel(for: currentRange))
            averageLine.lineColor = AppColors.brand
            averageLine.lineWidth = 1.0
            averageLine.lineDashLengths = [4, 4]
            averageLine.labelPosition = .rightTop
            averageLine.valueFont = MintFont.space(size: 9, weight: .medium)
            averageLine.valueTextColor = AppColors.brand
            leftAxis.addLimitLine(averageLine)
        }
        leftAxis.drawLimitLinesBehindDataEnabled = false

        if animate {
            barChartView.animate(yAxisDuration: 0.8, easingOption: .easeInOutQuart)
        } else {
            barChartView.notifyDataSetChanged()
        }
    }

    private func makeDailyBuckets() -> [SummaryBucket] {
        guard let interval = periodInterval(for: .daily, anchor: selectedAnchorDate) else { return [] }
        let dayTransactions = expenseTransactions.filter { interval.contains($0.timestamp) }

        return dayTransactions.map {
            SummaryBucket(
                label: hourFormatter.string(from: $0.timestamp),
                expense: $0.amount,
                budget: currentBudget?.dailyLimit ?? 0,
                startDate: $0.timestamp,
                endDate: $0.timestamp,
                transactionId: $0.id
            )
        }
    }

    private func makeWeeklyBuckets() -> [SummaryBucket] {
        guard let weekInterval = periodInterval(for: .weekly, anchor: selectedAnchorDate) else { return [] }
        let startOfWeek = weekInterval.start

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { return nil }
            let total = expenseTransactions
                .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
                .reduce(0) { $0 + $1.amount }
            let label = shortDayFormatter.string(from: date).uppercased()
            let endDate = calendar.date(byAdding: .day, value: 1, to: date)
            return SummaryBucket(
                label: label,
                expense: total,
                budget: currentBudget?.dailyLimit ?? 0,
                startDate: date,
                endDate: endDate,
                transactionId: nil
            )
        }
    }

    private func makeMonthlyBuckets() -> [SummaryBucket] {
        let range = calendar.range(of: .day, in: .month, for: selectedAnchorDate) ?? 1..<31
        let month = calendar.component(.month, from: selectedAnchorDate)
        let year = calendar.component(.year, from: selectedAnchorDate)

        return range.compactMap { day in
            let total = expenseTransactions
                .filter {
                    let components = calendar.dateComponents([.year, .month, .day], from: $0.timestamp)
                    return components.year == year && components.month == month && components.day == day
                }
                .reduce(0) { $0 + $1.amount }

            let startDate = calendar.date(from: DateComponents(year: year, month: month, day: day))
            let endDate = startDate.flatMap {
                calendar.date(byAdding: .day, value: 1, to: $0)
            }

            return SummaryBucket(
                label: "\(day)",
                expense: total,
                budget: currentBudget?.dailyLimit ?? 0,
                startDate: startDate,
                endDate: endDate,
                transactionId: nil
            )
        }
    }

    private func makeYearlyBuckets() -> [SummaryBucket] {
        let targetYear = calendar.component(.year, from: selectedAnchorDate)

        return (1...12).map { month in
            let total = expenseTransactions
                .filter {
                    let components = calendar.dateComponents([.year, .month], from: $0.timestamp)
                    return components.year == targetYear && components.month == month
                }
                .reduce(0) { $0 + $1.amount }

            let startDate = calendar.date(from: DateComponents(year: targetYear, month: month, day: 1))
            let endDate = startDate.flatMap {
                calendar.date(byAdding: .month, value: 1, to: $0)
            }

            return SummaryBucket(
                label: shortMonthName(for: month),
                expense: total,
                budget: currentBudget?.allocatedBudget ?? 0,
                startDate: startDate,
                endDate: endDate,
                transactionId: nil
            )
        }
    }

    private func makeDailyDetails() -> [SummaryDetailItem] {
        guard let interval = periodInterval(for: .daily, anchor: selectedAnchorDate) else { return [] }
        return expenseTransactions
            .filter { interval.contains($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
            .map { SummaryDetailItem(title: timeFormatter.string(from: $0.timestamp), amount: $0.amount) }
    }

    private func makeWeeklyDetails() -> [SummaryDetailItem] {
        makeWeeklyBuckets()
            .filter { $0.expense > 0 }
            .map { SummaryDetailItem(title: $0.label, amount: $0.expense) }
    }

    private func makeMonthlyDetails() -> [SummaryDetailItem] {
        makeMonthlyBuckets()
            .filter { $0.expense > 0 }
            .map { SummaryDetailItem(title: "Day \($0.label)", amount: $0.expense) }
    }

    private func makeYearlyDetails() -> [SummaryDetailItem] {
        makeYearlyBuckets()
            .filter { $0.expense > 0 }
            .map { SummaryDetailItem(title: $0.label, amount: $0.expense) }
    }

    private func details(for transactions: [Transaction], includeDate: Bool = false) -> [SummaryDetailItem] {
        transactions
            .sorted { $0.timestamp < $1.timestamp }
            .map { transaction in
                let title = includeDate
                    ? "\(shortDateFormatter.string(from: transaction.timestamp)), \(timeFormatter.string(from: transaction.timestamp))"
                    : timeFormatter.string(from: transaction.timestamp)
                return SummaryDetailItem(title: title, amount: transaction.amount)
            }
    }

    private func transactions(in bucket: SummaryBucket) -> [Transaction] {
        if let transactionId = bucket.transactionId {
            return expenseTransactions.filter { $0.id == transactionId }
        }

        guard let startDate = bucket.startDate,
              let endDate = bucket.endDate
        else { return [] }

        return expenseTransactions.filter {
            $0.timestamp >= startDate && $0.timestamp < endDate
        }
    }

    private func budgetLimit(for timeRange: TimeRange) -> Double {
        guard let currentBudget else { return 0 }

        switch timeRange {
        case .daily:
            return currentBudget.dailyLimit
        case .weekly:
            return currentBudget.dailyLimit * 7
        case .monthly:
            return currentBudget.allocatedBudget
        case .yearly:
            return currentBudget.allocatedBudget * 12
        }
    }

    private func averageLimitLabel(for timeRange: TimeRange) -> String {
        switch timeRange {
        case .daily:
            return "Daily avg"
        case .weekly:
            return "Weekly avg"
        case .monthly:
            return "Monthly avg"
        case .yearly:
            return "Yearly avg"
        }
    }

    private func selectDetails(for bucket: SummaryBucket) {
        let selectedTransactions = transactions(in: bucket)
        currentDetails = details(
            for: selectedTransactions,
            includeDate: currentRange == .yearly
        )
        updateDetailsHeading(for: currentRange, selectedBucket: bucket)
        monthlyDetailsCollectionView.reloadData()
        DispatchQueue.main.async { self.updateDetailsSectionHeight() }
    }

    private func averageAmount(for timeRange: TimeRange, buckets: [SummaryBucket]) -> Double {
        guard !buckets.isEmpty else { return 0 }

        let total = buckets.reduce(0) { $0 + $1.expense }
        guard total > 0 else { return 0 }

        return total / averageDivisor(for: timeRange)
    }

    private func averageDivisor(for timeRange: TimeRange) -> Double {
        switch timeRange {
        case .daily:
            return 1

        case .weekly:
            guard isCurrentPeriod(for: .weekly),
                  let weekInterval = periodInterval(for: .weekly, anchor: selectedAnchorDate) else {
                return 7
            }

            let weekStart = calendar.startOfDay(for: weekInterval.start)
            let today = calendar.startOfDay(for: Date())
            let elapsedDays = calendar.dateComponents([.day], from: weekStart, to: today).day ?? 0
            return Double(min(max(elapsedDays + 1, 1), 7))

        case .monthly:
            if isCurrentPeriod(for: .monthly) {
                return Double(max(calendar.component(.day, from: Date()), 1))
            }
            return Double(calendar.range(of: .day, in: .month, for: selectedAnchorDate)?.count ?? 30)

        case .yearly:
            if isCurrentPeriod(for: .yearly) {
                return Double(max(calendar.component(.month, from: Date()), 1))
            }
            return 12
        }
    }

    private func chartAxisMaximum(for values: [Double]) -> Double {
        guard let largestValue = values.max(), largestValue > 0 else { return 1 }

        return largestValue * 1.15
    }

    private func chartAxisMaximum(for values: [Double], isPlaceholder: Bool) -> Double {
        if isPlaceholder {
            return 1000
        }

        return chartAxisMaximum(for: values)
    }

    private func placeholderLabels(for range: TimeRange) -> [String] {
        switch range {
        case .daily:
            return ["12A", "6A", "12P", "6P", "11P"]
        case .weekly:
            guard let interval = periodInterval(for: .weekly, anchor: selectedAnchorDate) else {
                return ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
            }

            let startOfWeek = interval.start
            return (0..<7).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else { return nil }
                return shortDayFormatter.string(from: date).uppercased()
            }
        case .monthly:
            let daysInMonth = calendar.range(of: .day, in: .month, for: selectedAnchorDate)?.count ?? 30
            var seenDays = Set<Int>()
            return [1, 7, 14, 21, daysInMonth]
                .filter { $0 <= daysInMonth && seenDays.insert($0).inserted }
                .map(String.init)
        case .yearly:
            return (1...12).map(shortMonthName(for:))
        }
    }

    private func comparisonPercent(for timeRange: TimeRange) -> Double? {
        let current = currentBuckets.reduce(0) { $0 + $1.expense }
        let previous: Double

        switch timeRange {
        case .daily:
            guard let previousInterval = periodInterval(for: .daily, anchor: shiftedAnchorDate(from: selectedAnchorDate, for: .daily, offset: -1)) else {
                return nil
            }
            previous = totalExpense(in: previousInterval)

        case .weekly:
            guard let previousInterval = periodInterval(for: .weekly, anchor: shiftedAnchorDate(from: selectedAnchorDate, for: .weekly, offset: -1)) else {
                return nil
            }
            previous = totalExpense(in: previousInterval)

        case .monthly:
            guard let previousInterval = periodInterval(for: .monthly, anchor: shiftedAnchorDate(from: selectedAnchorDate, for: .monthly, offset: -1)) else {
                return nil
            }
            previous = totalExpense(in: previousInterval)

        case .yearly:
            guard let previousInterval = periodInterval(for: .yearly, anchor: shiftedAnchorDate(from: selectedAnchorDate, for: .yearly, offset: -1)) else {
                return nil
            }
            previous = totalExpense(in: previousInterval)
        }

        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }

    private func updatePeriodNavigationUI() {
        currentPeriodLabel.text = periodDisplayTitle(for: currentRange, anchor: selectedAnchorDate)

        let nextEnabled = canNavigateForward
        nextPeriodButton.isEnabled = nextEnabled
        nextPeriodButton.alpha = nextEnabled ? 1 : 0.45
        nextPeriodButton.tintColor = nextEnabled ? AppColors.brand : AppColors.textSecondary

        previousPeriodButton.isEnabled = true
        previousPeriodButton.alpha = 1
        previousPeriodButton.tintColor = AppColors.brand
    }

    private var canNavigateForward: Bool {
        guard let selectedInterval = periodInterval(for: currentRange, anchor: selectedAnchorDate),
              let currentInterval = periodInterval(for: currentRange, anchor: Date()) else {
            return false
        }

        return selectedInterval.start < currentInterval.start
    }

    private func clampedAnchorDate(_ date: Date, for range: TimeRange) -> Date {
        guard let proposedInterval = periodInterval(for: range, anchor: date),
              let currentInterval = periodInterval(for: range, anchor: Date()) else {
            return date
        }

        return proposedInterval.start > currentInterval.start ? Date() : date
    }

    private func shiftedAnchorDate(from date: Date, for range: TimeRange, offset: Int) -> Date {
        let baseDate = periodInterval(for: range, anchor: date)?.start ?? date

        switch range {
        case .daily:
            return calendar.date(byAdding: .day, value: offset, to: baseDate) ?? baseDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: offset, to: baseDate) ?? baseDate
        case .monthly:
            return calendar.date(byAdding: .month, value: offset, to: baseDate) ?? baseDate
        case .yearly:
            return calendar.date(byAdding: .year, value: offset, to: baseDate) ?? baseDate
        }
    }

    private func periodInterval(for range: TimeRange, anchor: Date) -> DateInterval? {
        switch range {
        case .daily:
            let start = calendar.startOfDay(for: anchor)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            return DateInterval(start: start, end: end)
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: anchor)
        case .monthly:
            return calendar.dateInterval(of: .month, for: anchor)
        case .yearly:
            return calendar.dateInterval(of: .year, for: anchor)
        }
    }

    private func isCurrentPeriod(for range: TimeRange) -> Bool {
        guard let selectedInterval = periodInterval(for: range, anchor: selectedAnchorDate),
              let currentInterval = periodInterval(for: range, anchor: Date()) else {
            return false
        }

        return selectedInterval.start == currentInterval.start
    }

    private func periodDisplayTitle(for range: TimeRange, anchor: Date) -> String {
        switch range {
        case .daily:
            return dayTitleFormatter.string(from: anchor)
        case .weekly:
            guard let interval = periodInterval(for: .weekly, anchor: anchor) else { return "" }
            let start = interval.start
            guard let endDate = calendar.date(byAdding: .day, value: -1, to: interval.end) else {
                return weekRangeFormatter.string(from: start)
            }

            let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: endDate)
            let sameMonth = sameYear && calendar.component(.month, from: start) == calendar.component(.month, from: endDate)

            if sameMonth {
                return "\(calendar.component(.day, from: start))-\(calendar.component(.day, from: endDate)) \(monthYearFormatter.string(from: start))"
            }

            if sameYear {
                return "\(shortDayMonthFormatter.string(from: start)) - \(shortDayMonthFormatter.string(from: endDate)) \(calendar.component(.year, from: start))"
            }

            return "\(shortDayMonthYearFormatter.string(from: start)) - \(shortDayMonthYearFormatter.string(from: endDate))"
        case .monthly:
            return monthYearFormatter.string(from: anchor)
        case .yearly:
            return yearFormatter.string(from: anchor)
        }
    }

    private func totalExpense(in interval: DateInterval) -> Double {
        expenseTransactions
            .filter { interval.contains($0.timestamp) }
            .reduce(0) { $0 + $1.amount }
    }

    private func placeholderMessage() -> String {
        switch currentRange {
        case .daily:
            return isCurrentPeriod(for: .daily) ? EmptyStateMessage.today : EmptyStateMessage.day
        case .weekly:
            return EmptyStateMessage.week
        case .monthly:
            return EmptyStateMessage.month
        case .yearly:
            return EmptyStateMessage.year
        }
    }

    private func setupCollectionView() {
        monthlyDetailsCollectionView.delegate = self
        monthlyDetailsCollectionView.dataSource = self
        monthlyDetailsCollectionView.isScrollEnabled = false
        monthlyDetailsCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
        monthlyDetailsCollectionView.register(
            UINib(nibName: "SummaryCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "SummaryCell"
        )
        monthlyDetailsCollectionView.register(
            UINib(nibName: PlaceHolderCollectionViewCell.nibName, bundle: nil),
            forCellWithReuseIdentifier: PlaceHolderCollectionViewCell.reuseIdentifier
        )

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 0
        monthlyDetailsCollectionView.collectionViewLayout = layout
    }

    private func updateScrollInsets() {
        let tabBarHeight = tabBarController?.tabBar.isHidden == false ? (tabBarController?.tabBar.bounds.height ?? 0) : 0
        let bottomInset = max(24, tabBarHeight + 12)
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    private func updateDetailsSectionHeight() {
        monthlyDetailsCollectionView.layoutIfNeeded()
        let contentHeight = monthlyDetailsCollectionView.collectionViewLayout.collectionViewContentSize.height
        let contentInsets = monthlyDetailsCollectionView.adjustedContentInset.top + monthlyDetailsCollectionView.adjustedContentInset.bottom
        let resolvedHeight = max(contentHeight + contentInsets, 1)
        detailsSectionHeightConstraint.constant = 40 + 8 + resolvedHeight
    }

    private func currencyString(_ value: Double) -> String {
        AppFormatters.currency(value)
    }

    private func shortMonthName(for month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.shortMonthSymbols[month - 1].uppercased()
    }

    private let hourFormatter = AppFormatters.hourOnly
    private let timeFormatter = AppFormatters.timeWithMeridiem
    private let shortDateFormatter = AppFormatters.shortDate
    private let shortDayFormatter = AppFormatters.shortWeekday
    private let dayTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    private let weekRangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    private let shortDayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()
    private let shortDayMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    private let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    private let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()
}

extension SummaryViewController: ChartViewDelegate {

    func chartValueSelected(_ chartView: ChartViewBase,
                            entry: ChartDataEntry,
                            highlight: Highlight) {
        let bucketIndex = Int(entry.x.rounded())
        guard currentBuckets.indices.contains(bucketIndex) else { return }
        selectDetails(for: currentBuckets[bucketIndex])
    }

    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        switch currentRange {
        case .daily:
            currentDetails = makeDailyDetails()
        case .weekly:
            currentDetails = makeWeeklyDetails()
        case .monthly:
            currentDetails = makeMonthlyDetails()
        case .yearly:
            currentDetails = makeYearlyDetails()
        }

        updateDetailsHeading(for: currentRange)
        monthlyDetailsCollectionView.reloadData()
        DispatchQueue.main.async { self.updateDetailsSectionHeight() }
    }
}

extension SummaryViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        max(currentDetails.count, 1)
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isShowingPlaceholder {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PlaceHolderCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as? PlaceHolderCollectionViewCell else {
                return UICollectionViewCell()
            }

            cell.configure(message: placeholderMessage(), sizeStyle: .fill)
            return cell
        }

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "SummaryCell",
            for: indexPath
        ) as? SummaryCollectionViewCell else {
            return UICollectionViewCell()
        }

        let item = currentDetails[indexPath.row]
        cell.configure(title: item.title, amount: item.amount, isPositive: false)
        return cell
    }
}

extension SummaryViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if isShowingPlaceholder {
            return CGSize(width: collectionView.bounds.width, height: max(collectionView.bounds.height, 120))
        }

        return CGSize(width: collectionView.bounds.width, height: 56)
    }
}
