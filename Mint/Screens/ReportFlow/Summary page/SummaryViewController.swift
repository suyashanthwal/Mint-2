
import UIKit
import DGCharts

class SummaryViewController: UIViewController {

    @IBOutlet weak var AverageHeadingLabel: UILabel!
    @IBOutlet weak var AmountLabel: UILabel!
    @IBOutlet weak var UPorDOWNPercentLabel: UILabel!
    @IBOutlet weak var detailsHeadingLabel: UILabel!

    @IBOutlet weak var barChartView: BarChartView!
    @IBOutlet weak var monthlyDetailsCollectionView: UICollectionView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!

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
    private var currentBudgetLimitLabel: String = ""
    private var currentRange: TimeRange = .daily

    private var expenseTransactions: [Transaction] {
        transactions
            .filter { $0.type == .expense }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var latestExpenseDate: Date {
        expenseTransactions.map(\.timestamp).max() ?? Date()
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
        reloadFromDatabase(animateChart: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
        applyReportNavigationTheme()
        reloadFromDatabase(animateChart: false)
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
                .font: UIFont.systemFont(ofSize: 13, weight: .medium)
            ],
            for: .normal
        )
        segmentedControl.setTitleTextAttributes(
            [
                .foregroundColor: AppColors.brandText,
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
            ],
            for: .selected
        )

        AverageHeadingLabel.textColor = AppColors.textSecondary
        AmountLabel.textColor = AppColors.brand
        UPorDOWNPercentLabel.textColor = AppColors.textSecondary
        detailsHeadingLabel.textColor = AppColors.textPrimary
        monthlyDetailsCollectionView.backgroundColor = .clear
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
            .font: UIFont.systemFont(ofSize: 20, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: AppColors.textPrimary
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
        barChartView.fitBars = true
        barChartView.delegate = self
    }

    private func reloadFromDatabase(animateChart: Bool) {
        transactions = db.fetchTransactions()
        currentBudget = db.fetchCurrentBudget()

        let timeRange = TimeRange(rawValue: segmentedControl.selectedSegmentIndex) ?? .daily
        updateChartData(for: timeRange, animateChart: animateChart)
    }

    @objc private func handleSummaryDataChange() {
        reloadFromDatabase(animateChart: false)
    }

    @IBAction
    func segmentedControlValueChanged(_ sender: UISegmentedControl) {
        guard let timeRange = TimeRange(rawValue: sender.selectedSegmentIndex) else { return }
        updateChartData(for: timeRange, animateChart: true)
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
        currentBudgetLimitLabel = budgetLimitLabel(for: timeRange)

        currentAverageAmount = averageAmount(for: timeRange, buckets: currentBuckets)
        currentComparisonPercent = comparisonPercent(for: timeRange)

        updateTopLabels(for: timeRange)
        updateDetailsHeading(for: timeRange)
        setupChart(labels: currentBuckets.map(\.label), barWidth: timeRange == .monthly ? 0.55 : 0.5, animate: animateChart)
        barChartView.highlightValue(nil)
        monthlyDetailsCollectionView.reloadData()
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
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
            ]
        )
        text.append(NSAttributedString(
            string: " vs last period",
            attributes: [
                .foregroundColor: AppColors.textSecondary,
                .font: UIFont.systemFont(ofSize: 16, weight: .regular)
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
                detailsHeadingLabel.text = "Today's Transactions"
            case .weekly:
                detailsHeadingLabel.text = "Weekly Breakdown"
            case .monthly:
                detailsHeadingLabel.text = "Monthly Breakdown"
            case .yearly:
                detailsHeadingLabel.text = "Yearly Breakdown"
            }
        }
    }

    private func setupChart(labels: [String], barWidth: Double, animate: Bool) {
        let entries = currentBuckets.enumerated().map {
            BarChartDataEntry(x: Double($0.offset), y: $0.element.expense)
        }

        let colors: [NSUIColor] = currentBuckets.map { bucket in
            if bucket.expense == 0 {
                return AppColors.brandLight
            } else if bucket.budget > 0, bucket.expense > bucket.budget {
                return AppColors.errorBackground
            } else {
                return AppColors.brand
            }
        }

        let dataSet = BarChartDataSet(entries: entries, label: "Expense")
        dataSet.colors = colors
        dataSet.drawValuesEnabled = false

        let data = BarChartData(dataSet: dataSet)
        data.barWidth = barWidth
        barChartView.data = data

        let xAxis = barChartView.xAxis
        xAxis.valueFormatter = IndexAxisValueFormatter(values: labels)
        xAxis.granularity = 1
        xAxis.centerAxisLabelsEnabled = false
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        xAxis.labelFont = .systemFont(ofSize: currentRange == .monthly ? 8 : 9, weight: .medium)
        xAxis.labelTextColor = AppColors.textSecondary
        xAxis.drawAxisLineEnabled = true
        xAxis.axisLineColor = AppColors.sectionBackground
        xAxis.axisMinimum = -0.5
        xAxis.axisMaximum = Double(max(currentBuckets.count, 1)) - 0.5

        let maxExpense = max(currentBuckets.map(\.expense).max() ?? 0, currentBudgetLimit, 100)
        let leftAxis = barChartView.leftAxis
        leftAxis.axisMinimum = 0
        leftAxis.axisMaximum = maxExpense * 1.2
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = AppColors.sectionBackground
        leftAxis.gridLineWidth = 0.5
        leftAxis.labelFont = .systemFont(ofSize: 9)
        leftAxis.labelTextColor = AppColors.textSecondary
        leftAxis.drawAxisLineEnabled = false
        leftAxis.setLabelCount(4, force: true)
        leftAxis.removeAllLimitLines()

        if currentBudgetLimit > 0 {
            let limitLine = ChartLimitLine(limit: currentBudgetLimit, label: currentBudgetLimitLabel)
            limitLine.lineColor = AppColors.brand
            limitLine.lineWidth = 1.0
            limitLine.lineDashLengths = [6, 4]
            limitLine.labelPosition = .rightTop
            limitLine.valueFont = .systemFont(ofSize: 9, weight: .medium)
            limitLine.valueTextColor = AppColors.brand
            leftAxis.addLimitLine(limitLine)
            leftAxis.drawLimitLinesBehindDataEnabled = false
        }

        if animate {
            barChartView.animate(yAxisDuration: 0.8, easingOption: .easeInOutQuart)
        } else {
            barChartView.notifyDataSetChanged()
        }
    }

    private func makeDailyBuckets() -> [SummaryBucket] {
        let calendar = Calendar.current
        let dayTransactions = expenseTransactions.filter { calendar.isDate($0.timestamp, inSameDayAs: latestExpenseDate) }

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
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: latestExpenseDate) else { return [] }
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
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: latestExpenseDate) ?? 1..<31
        let month = calendar.component(.month, from: latestExpenseDate)
        let year = calendar.component(.year, from: latestExpenseDate)

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
        let calendar = Calendar.current
        let targetYear = calendar.component(.year, from: latestExpenseDate)

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
        let calendar = Calendar.current
        return expenseTransactions
            .filter { calendar.isDate($0.timestamp, inSameDayAs: latestExpenseDate) }
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

    private func budgetLimitLabel(for timeRange: TimeRange) -> String {
        switch timeRange {
        case .daily:
            return "Daily average limit"
        case .weekly:
            return "Weekly average limit"
        case .monthly:
            return "Monthly average limit"
        case .yearly:
            return "Yearly average limit"
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
    }

    private func averageAmount(for timeRange: TimeRange, buckets: [SummaryBucket]) -> Double {
        let nonZeroBuckets = buckets.filter { $0.expense > 0 }
        guard !nonZeroBuckets.isEmpty else { return 0 }

        switch timeRange {
        case .daily:
            return nonZeroBuckets.reduce(0) { $0 + $1.expense } / Double(nonZeroBuckets.count)
        case .weekly:
            return buckets.reduce(0) { $0 + $1.expense } / 7.0
        case .monthly:
            return buckets.reduce(0) { $0 + $1.expense } / Double(buckets.count)
        case .yearly:
            return buckets.reduce(0) { $0 + $1.expense } / 12.0
        }
    }

    private func comparisonPercent(for timeRange: TimeRange) -> Double? {
        let current = currentBuckets.reduce(0) { $0 + $1.expense }
        let previous: Double
        let calendar = Calendar.current

        switch timeRange {
        case .daily:
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: latestExpenseDate) else { return nil }
            previous = expenseTransactions
                .filter { calendar.isDate($0.timestamp, inSameDayAs: previousDate) }
                .reduce(0) { $0 + $1.amount }

        case .weekly:
            guard let previousDate = calendar.date(byAdding: .day, value: -7, to: latestExpenseDate),
                  let previousWeek = calendar.dateInterval(of: .weekOfYear, for: previousDate) else { return nil }
            previous = expenseTransactions
                .filter { previousWeek.contains($0.timestamp) }
                .reduce(0) { $0 + $1.amount }

        case .monthly:
            guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: latestExpenseDate) else { return nil }
            let previousMonth = calendar.component(.month, from: previousMonthDate)
            let previousYear = calendar.component(.year, from: previousMonthDate)
            previous = expenseTransactions
                .filter {
                    let components = calendar.dateComponents([.year, .month], from: $0.timestamp)
                    return components.year == previousYear && components.month == previousMonth
                }
                .reduce(0) { $0 + $1.amount }

        case .yearly:
            let previousYear = calendar.component(.year, from: latestExpenseDate) - 1
            previous = expenseTransactions
                .filter { calendar.component(.year, from: $0.timestamp) == previousYear }
                .reduce(0) { $0 + $1.amount }
        }

        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }

    private func setupCollectionView() {
        monthlyDetailsCollectionView.delegate = self
        monthlyDetailsCollectionView.dataSource = self
        monthlyDetailsCollectionView.register(
            UINib(nibName: "SummaryCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "SummaryCell"
        )

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        monthlyDetailsCollectionView.collectionViewLayout = layout
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
    }
}

extension SummaryViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        currentDetails.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
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
        CGSize(width: collectionView.bounds.width, height: 56)
    }
}
