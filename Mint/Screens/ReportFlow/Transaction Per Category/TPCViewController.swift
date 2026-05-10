
import UIKit
import DGCharts

class TPCViewController: UIViewController {

    @IBOutlet weak var pieChartView: PieChartView!
    @IBOutlet weak var PerCategoryCollectionView: UICollectionView!
    @IBOutlet weak var SpendingBreakdownHeadingLabel: UILabel!
    @IBOutlet weak var MonthCollectionView: UICollectionView!
    @IBOutlet weak var perCategorySectionHeightConstraint: NSLayoutConstraint!

    @IBOutlet var AllBackgroundVIews: [UIView]!
    @IBOutlet var AllCardVIews: [UIView]!

    private enum DisplayMode {
        case summary
        case details
    }

    private let db = DatabaseManager.shared

    private var displayMode: DisplayMode = .summary
    private var selectedCategoryId: UUID?
    private var allTransactions: [Transaction] = []
    private var allCategories: [Category] = []
    private var reportYear = Calendar.current.component(.year, from: Date())
    private var hasInitializedMonthSelection = false

    private let cellId = "TPCcell"
    private let monthCellId = "MonthStripCollectionViewCell"

    private let allMonths = [
        "January", "February", "March", "April",
        "May", "June", "July", "August",
        "September", "October", "November", "December"
    ]

    private var months: [String] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let maxMonth = reportYear == currentYear
            ? Calendar.current.component(.month, from: Date())
            : allMonths.count

        return Array(allMonths.prefix(max(maxMonth, 1)))
    }

    private var selectedMonthIndex: Int = Calendar.current.component(.month, from: Date()) - 1

    private var expenseTransactions: [Transaction] {
        let calendar = Calendar.current

        return allTransactions.filter {
            $0.type == .expense &&
            calendar.component(.month, from: $0.timestamp) == selectedMonthIndex + 1 &&
            calendar.component(.year, from: $0.timestamp) == reportYear
        }
    }

    private var categorySummaries: [(category: Category, total: Double)] {
        var summaries: [(category: Category, total: Double)] = []

        for category in allCategories {
            let total = expenseTransactions
                .filter { $0.categoryId == category.id }
                .reduce(0) { $0 + $1.amount }

            if total > 0 {
                summaries.append((category: category, total: total))
            }
        }

        return summaries.sorted { $0.total > $1.total }
    }

    private var selectedTransactions: [Transaction] {
        guard let id = selectedCategoryId else { return [] }

        return expenseTransactions
            .filter { $0.categoryId == id }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var totalExpense: Double {
        expenseTransactions.reduce(0) { $0 + $1.amount }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMonthCollectionView()
        setupCollectionView()
        setupDonutChart()
        reloadFromDatabase(animateChart: true, preserveSelection: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
        applyReportNavigationTheme()
        reloadFromDatabase(animateChart: false, preserveSelection: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePerCategorySectionHeight()
    }

    private func setupUI() {
        applyReportBackgroundTheme(to: view)
        for view in AllBackgroundVIews { view.backgroundColor = AppColors.background }
        for card in AllCardVIews {
            card.backgroundColor = AppColors.card
            card.applyShadow()
        }

        SpendingBreakdownHeadingLabel.textColor = AppColors.textPrimary
        MonthCollectionView.backgroundColor = .clear
        PerCategoryCollectionView.backgroundColor = .clear
        view.backgroundColor = AppColors.background
    }

    private func applyReportBackgroundTheme(to parent: UIView) {
        switch parent {
        case is UIStackView:
            parent.backgroundColor = .clear
        case is UILabel, is UIButton:
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
            .font: UIFont.systemFont(ofSize: 28, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: AppColors.textPrimary
        ]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = AppColors.textPrimary
    }

    private func reloadFromDatabase(animateChart: Bool, preserveSelection: Bool) {
        allTransactions = db.fetchTransactions()
        allCategories = db.fetchCategories()

        let referenceDate = allTransactions
            .filter { $0.type == .expense }
            .map(\.timestamp)
            .max() ?? Date()

        reportYear = Calendar.current.component(.year, from: referenceDate)
        let referenceMonthIndex = Calendar.current.component(.month, from: referenceDate) - 1

        if !preserveSelection || !hasInitializedMonthSelection {
            selectedMonthIndex = min(referenceMonthIndex, max(months.count - 1, 0))
            hasInitializedMonthSelection = true
        } else {
            selectedMonthIndex = min(selectedMonthIndex, max(months.count - 1, 0))
        }

        if let selectedCategoryId,
           !categorySummaries.contains(where: { $0.category.id == selectedCategoryId }) {
            self.selectedCategoryId = nil
            displayMode = .summary
        }

        MonthCollectionView.reloadData()
        refreshDonutChart(animate: animateChart)
        updateHeading()
        PerCategoryCollectionView.reloadData()

        DispatchQueue.main.async {
            guard self.months.indices.contains(self.selectedMonthIndex) else { return }
            self.MonthCollectionView.scrollToItem(
                at: IndexPath(item: self.selectedMonthIndex, section: 0),
                at: .centeredHorizontally,
                animated: false
            )
            self.updatePerCategorySectionHeight()
        }
    }

    private func setupMonthCollectionView() {
        MonthCollectionView.delegate = self
        MonthCollectionView.dataSource = self
        MonthCollectionView.showsHorizontalScrollIndicator = false
        MonthCollectionView.register(
            UINib(nibName: "MonthStripCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: monthCellId
        )
    }

    private func setupCollectionView() {
        PerCategoryCollectionView.delegate = self
        PerCategoryCollectionView.dataSource = self
        PerCategoryCollectionView.isScrollEnabled = false
        PerCategoryCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        PerCategoryCollectionView.register(
            UINib(nibName: "TPCCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: cellId
        )

        if let layout = PerCategoryCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.minimumLineSpacing = 8
            layout.minimumInteritemSpacing = 0
        }
    }

    private func setupDonutChart() {
        pieChartView.drawHoleEnabled = true
        pieChartView.holeRadiusPercent = 0.65
        pieChartView.transparentCircleRadiusPercent = 0.68
        pieChartView.holeColor = AppColors.background
        pieChartView.legend.enabled = false
        pieChartView.drawEntryLabelsEnabled = false
        pieChartView.chartDescription.enabled = false
        pieChartView.rotationEnabled = false
        pieChartView.highlightPerTapEnabled = true
        pieChartView.backgroundColor = AppColors.background
        pieChartView.delegate = self
    }

    private func refreshDonutChart(animate: Bool = false) {
        let entries = categorySummaries.map {
            PieChartDataEntry(value: $0.total, label: $0.category.name)
        }

        let dataSet = PieChartDataSet(entries: entries)
        dataSet.colors = categorySummaries.map { UIColor(hex: $0.category.color) }
        dataSet.drawValuesEnabled = false
        dataSet.sliceSpace = 4
        dataSet.selectionShift = 12

        pieChartView.data = PieChartData(dataSet: dataSet)
        pieChartView.notifyDataSetChanged()
        updateCenterText(category: nil, amount: totalExpense)

        if animate {
            pieChartView.animate(yAxisDuration: 1.2, easingOption: .easeOutCubic)
        }
    }

    private func updatePieChartColors(selectedName: String?) {
        guard let dataSet = pieChartView.data?.dataSets.first as? PieChartDataSet else { return }
        dataSet.colors = categorySummaries.map { item in
            let base = UIColor(hex: item.category.color)
            guard let selectedName else { return base }
            return item.category.name == selectedName ? base : base.withAlphaComponent(0.25)
        }
        pieChartView.notifyDataSetChanged()
    }

    private func updateCenterText(category: Category?, amount: Double) {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center

        let text = NSMutableAttributedString()
        text.append(NSAttributedString(
            string: "\(category?.name ?? "Total")\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: AppColors.textSecondary,
                .paragraphStyle: centered
            ]
        ))
        text.append(NSAttributedString(
            string: amount.formatted(.currency(code: "INR")),
            attributes: [
                .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: AppColors.textPrimary,
                .paragraphStyle: centered
            ]
        ))
        pieChartView.centerAttributedText = text
    }

    private func updateHeading() {
        switch displayMode {
        case .summary:
            SpendingBreakdownHeadingLabel.text = "Spending Breakdown"
        case .details:
            let name = categorySummaries.first { $0.category.id == selectedCategoryId }?.category.name ?? ""
            SpendingBreakdownHeadingLabel.text = "\(name) Transactions"
        }
    }

    private func updatePerCategorySectionHeight() {
        PerCategoryCollectionView.layoutIfNeeded()
        let contentHeight = PerCategoryCollectionView.collectionViewLayout.collectionViewContentSize.height
            + PerCategoryCollectionView.adjustedContentInset.top
            + PerCategoryCollectionView.adjustedContentInset.bottom
        let resolvedHeight = max(contentHeight, 1)
        perCategorySectionHeightConstraint.constant = 16 + 19.333333333333329 + 16 + resolvedHeight + 16
    }
}

extension TPCViewController: ChartViewDelegate {

    func chartValueSelected(_ chartView: ChartViewBase,
                            entry: ChartDataEntry,
                            highlight: Highlight) {
        guard let pieEntry = entry as? PieChartDataEntry,
              let summary = categorySummaries.first(where: { $0.category.name == pieEntry.label })
        else { return }

        selectedCategoryId = summary.category.id
        displayMode = .details

        updatePieChartColors(selectedName: summary.category.name)
        updateCenterText(category: summary.category, amount: summary.total)
        updateHeading()
        PerCategoryCollectionView.reloadData()
        DispatchQueue.main.async { self.updatePerCategorySectionHeight() }
    }

    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        selectedCategoryId = nil
        displayMode = .summary

        updatePieChartColors(selectedName: nil)
        updateCenterText(category: nil, amount: totalExpense)
        updateHeading()
        PerCategoryCollectionView.reloadData()
        DispatchQueue.main.async { self.updatePerCategorySectionHeight() }
    }
}

extension TPCViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === MonthCollectionView {
            return months.count
        }

        switch displayMode {
        case .summary:
            return categorySummaries.count
        case .details:
            return selectedTransactions.count
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView === MonthCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: monthCellId,
                for: indexPath
            ) as! MonthStripCollectionViewCell
            cell.configure(
                month: months[indexPath.item],
                year: reportYear,
                isSelected: indexPath.item == selectedMonthIndex
            )
            return cell
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: cellId,
            for: indexPath
        ) as! TPCCollectionViewCell

        switch displayMode {
        case .summary:
            let item = categorySummaries[indexPath.item]
            let count = expenseTransactions.filter { $0.categoryId == item.category.id }.count
            cell.configure(
                with: item.category,
                total: item.total,
                transactionCount: count,
                totalExpense: totalExpense
            )

        case .details:
            let transaction = selectedTransactions[indexPath.item]
            let category = allCategories.first { $0.id == transaction.categoryId }
                ?? Category(name: "Other", color: "#8E8E93", icon: "questionmark.circle", budget: 0)
            cell.configure(with: transaction, category: category)
        }

        return cell
    }
}

extension TPCViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard collectionView === MonthCollectionView else { return }
        guard indexPath.item != selectedMonthIndex else { return }

        let previous = selectedMonthIndex
        selectedMonthIndex = indexPath.item
        selectedCategoryId = nil
        displayMode = .summary

        MonthCollectionView.reloadItems(at: [
            IndexPath(item: previous, section: 0),
            IndexPath(item: selectedMonthIndex, section: 0)
        ])
        MonthCollectionView.scrollToItem(
            at: IndexPath(item: selectedMonthIndex, section: 0),
            at: .centeredHorizontally,
            animated: true
        )

        refreshDonutChart()
        updatePieChartColors(selectedName: nil)
        updateHeading()
        self.PerCategoryCollectionView.reloadData()
        DispatchQueue.main.async { self.updatePerCategorySectionHeight() }
    }
}

extension TPCViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView === MonthCollectionView {
            return CGSize(width: 140, height: 40)
        }

        return CGSize(width: collectionView.bounds.width - 32, height: 80)
    }
}
