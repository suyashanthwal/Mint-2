
import UIKit

struct ReportsInsightsPayload: Codable {

    struct SummarySection: Codable {
        let monthName: String
        let year: Int
        let daysElapsed: Int
        let daysInMonth: Int
        let totalExpense: Double
        let totalIncome: Double
        let dailyAverage: Double
        let previousMonthAverage: Double?
        let transactionCount: Int
        let highestSpendDay: Int?
        let highestSpendDayAmount: Double?
        let budget: Double?
        let remainingBudget: Double?
    }

    struct CategoryItem: Codable {
        let name: String
        let amount: Double
        let sharePercent: Int
        let budget: Double?
    }

    struct CategorySection: Codable {
        let totalExpense: Double
        let categoryCount: Int
        let topCategories: [CategoryItem]
    }

    struct SubsAndBillsSection: Codable {
        let monthName: String
        let unpaidBillsCount: Int
        let upcomingBillsTotal: Double
        let nextBillName: String?
        let nextBillAmount: Double?
        let nextBillDueDate: String?
        let daysUntilNextBill: Int?
        let activeSubscriptionCount: Int
        let monthlySubscriptionTotal: Double
    }

    let summary: SummarySection
    let category: CategorySection
    let subsAndBills: SubsAndBillsSection
}

struct ReportsInsightsEnvelope: Codable {
    let payload: ReportsInsightsPayload
    let fields: [String]
    let forceRefresh: Bool
}

struct ReportsInsightsResponse: Codable {
    let summary: String?
    let categoryHighlight: String?
    let subsAndBills: String?
}

class ReportsViewController: UIViewController {

    private enum EmptyStateMessage {
        static let topCategories = "Your top 4 categories will be shown here once you log transactions."
    }

    private enum InsightCardStyle {
        static let bulbImageViewTag = 9201
        static let height: CGFloat = 120
        static let imageWidth: CGFloat = 80
        static let textLeading: CGFloat = 84
        static let textTrailing: CGFloat = 40
    }

    private var hasCheckedOnboarding = false

    @IBOutlet weak var subsAndBillsView: UIView!
    @IBOutlet weak var subsAndBillsInsightView: UIView!
    @IBOutlet weak var categoryBreakdownView: UIView!
    @IBOutlet weak var categoryInsightView: UIView!
    @IBOutlet weak var summaryView: UIView!
    @IBOutlet weak var summaryInsightVIew: UIView!
    @IBOutlet weak var MainScrollView: UIScrollView!
    @IBOutlet weak var SummaryCard: UICollectionView!
    @IBOutlet weak var CategoryBreakdownDataEntry: UICollectionView!
    @IBOutlet weak var CategoryBreakdown: UICollectionView!
    @IBOutlet weak var SubsAndBillsCard: UICollectionView?
    
    
    @IBOutlet weak var CategoryBreakdownButton: UIButton!
    @IBOutlet weak var SummaryButton: UIButton!
    @IBOutlet weak var SubsAndBillsButton: UIButton!
    
    private let db = DatabaseManager.shared
    @IBOutlet weak var subsAndBillsInsightLabel: UILabel!
    @IBOutlet weak var categoryInsightLabel: UILabel!
    @IBOutlet weak var summaryInsightLabel: UILabel!
    @IBOutlet private weak var profileButton: UIButton!
    
    
    private var transactions: [Transaction] = []
    private var categories: [Category] = []
    private var bills: [Bill] = []
    private var recurringPayments: [RecurringPayment] = []

    private var dailyData: [DailySpending] = []
    private var dailyAverage: Double?
    private var previousMonthAverage: Double?
    private var categoryData: [CategorySpending] = []
    private var subsBillsCalendarData: SubsBillsCalendarData?
    private var insightTask: Task<Void, Never>?
    private var hasLoadedOnce = false

    private var spotlightView: OnboardingSpotlightView?
    private var currentOnboardingStep = 0
    private var onboardingSteps: [OnboardingStep] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionViews()
        onboardingSteps = [
            OnboardingStep(
                view: summaryView,
                title: "Summary",
                message: "Review your month-to-date spending trend and average in one place.",
                tooltipBelow: true
            ),
            OnboardingStep(
                view: categoryBreakdownView,
                title: "Category Breakdown",
                message: "See which categories are driving your spending this month.",
                tooltipBelow: false
            ),
            OnboardingStep(
                view: subsAndBillsView,
                title: "Subscriptions & Bills",
                message: "Track your recurring payments and upcoming bills without leaving analysis.",
                tooltipBelow: false
            ),
        ]
        hasLoadedOnce = true
        reloadReports()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReportDataChange),
            name: .transactionDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReportDataChange),
            name: .categoryDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReportDataChange),
            name: .budgetDataDidChange,
            object: nil
        )
    }

    @IBAction func crossTappedOnInsight(_ sender: UIButton) {
        switch sender.tag {
            case 1: summaryInsightVIew.isHidden = true
            case 2: categoryInsightView.isHidden = true
            case 3: subsAndBillsInsightView.isHidden = true
            default: break
            }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true
        reloadReports()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasCheckedOnboarding else { return }
        hasCheckedOnboarding = true

        if OnboardingHelper.shouldShow(key: OnboardingKeys.reports) {
            showReportsOnboarding()
            OnboardingHelper.markSeen(key: OnboardingKeys.reports)
        }
    }
    
    private func applyTopCornerRadius(to collectionView: UICollectionView) {
        collectionView.layer.cornerRadius = 22
        collectionView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]
        collectionView.clipsToBounds = true
    }
    
    private func applyBottomCornerRadius(to collectionView: UICollectionView) {
        collectionView.layer.cornerRadius = 22
        collectionView.layer.maskedCorners = [
            .layerMinXMaxYCorner, // bottom-left
            .layerMaxXMaxYCorner  // bottom-right
        ]
        collectionView.clipsToBounds = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateCardLayouts()
        
        applyBottomCornerRadius(to: CategoryBreakdownDataEntry)
        applyTopCornerRadius(to: CategoryBreakdown)
    }

    deinit {
        insightTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    private var expenseTransactions: [Transaction] {
        transactions.filter { $0.type == .expense }
    }

    private var activeRecurringExpenses: [RecurringPayment] {
        recurringPayments.filter { $0.isActive && !$0.isIncome }
    }

    private func recurringEventDates(for subscription: RecurringPayment, year: Int, month: Int) -> [Date] {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
        let anchorDate = calendar.startOfDay(for: subscription.nextDate)
        guard monthEnd >= anchorDate else { return [] }

        switch subscription.duration {
        case .daily:
            let startDay = calendar.isDate(anchorDate, equalTo: monthStart, toGranularity: .month)
                ? calendar.component(.day, from: anchorDate)
                : dayRange.lowerBound
            return (startDay..<dayRange.upperBound).compactMap {
                calendar.date(from: DateComponents(year: year, month: month, day: $0))
            }

        case .weekly:
            let weekday = calendar.component(.weekday, from: anchorDate)
            return dayRange.compactMap { day -> Date? in
                guard let candidate = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                      candidate >= anchorDate,
                      calendar.component(.weekday, from: candidate) == weekday
                else { return nil }
                return candidate
            }

        case .monthly, .quarterly, .halfYearly, .yearly:
            let anchorMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: anchorDate)) ?? anchorDate
            let anchorComponents = calendar.dateComponents([.year, .month, .day], from: anchorDate)
            guard let anchorYear = anchorComponents.year,
                  let anchorMonth = anchorComponents.month,
                  let anchorDay = anchorComponents.day,
                  monthStart >= anchorMonthStart
            else { return [] }

            let monthDelta = (year - anchorYear) * 12 + (month - anchorMonth)
            let stride: Int

            switch subscription.duration {
            case .monthly:
                stride = 1
            case .quarterly:
                stride = 3
            case .halfYearly:
                stride = 6
            case .yearly:
                stride = 12
            case .daily, .weekly:
                stride = 1
            }

            guard monthDelta >= 0, monthDelta % stride == 0 else { return [] }
            let day = min(anchorDay, dayRange.upperBound - 1)
            return calendar.date(from: DateComponents(year: year, month: month, day: day)).map { [$0] } ?? []
        }
    }
    
    @objc private func showProfile() {
        guard let profile = storyboard?.instantiateViewController(withIdentifier: "ProfileViewController") else { return }
        navigationController?.pushViewController(profile, animated: true)
    }


    private func nextRecurringEventDate(for subscription: RecurringPayment, onOrAfter date: Date) -> Date? {
        let calendar = Calendar.current
        let searchStart = calendar.startOfDay(for: date)
        let startComponents = calendar.dateComponents([.year, .month], from: min(subscription.nextDate, searchStart))

        guard let startYear = startComponents.year,
              let startMonth = startComponents.month
        else { return subscription.nextDate }

        for offset in 0..<24 {
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: calendar.date(from: DateComponents(year: startYear, month: startMonth, day: 1)) ?? searchStart) else {
                continue
            }
            let year = calendar.component(.year, from: monthDate)
            let month = calendar.component(.month, from: monthDate)
            if let occurrence = recurringEventDates(for: subscription, year: year, month: month)
                .first(where: { calendar.startOfDay(for: $0) >= searchStart }) {
                return occurrence
            }
        }

        return nil
    }

    private func setupUI() {
        
        view.backgroundColor = AppColors.background
        MainScrollView.backgroundColor = AppColors.background
        SummaryCard.backgroundColor = AppColors.card
        CategoryBreakdownDataEntry.backgroundColor = AppColors.card
        CategoryBreakdown.backgroundColor = AppColors.card
        SubsAndBillsCard?.backgroundColor = AppColors.card
        
        CategoryBreakdownButton.tintColor = AppColors.accent
        SummaryButton.tintColor = AppColors.accent
        SubsAndBillsButton.tintColor = AppColors.accent
        
        profileButton.tintColor = AppColors.background
        profileButton.backgroundColor = AppColors.textPrimary
        profileButton.layer.cornerRadius = 17
        profileButton.addTarget(self, action: #selector(showProfile), for: .touchUpInside)

        
        configureInsightCard(summaryInsightVIew, label: summaryInsightLabel)
        configureInsightCard(categoryInsightView, label: categoryInsightLabel)
        configureInsightCard(subsAndBillsInsightView, label: subsAndBillsInsightLabel)
    }

    private func configureInsightCard(_ insightView: UIView?, label: UILabel?) {
        guard let insightView, let label else { return }

        insightView.backgroundColor = .clear
        insightView.isHidden = true
        insightView.constraints
            .filter { $0.firstAttribute == .height }
            .forEach { $0.constant = InsightCardStyle.height }

        let cardView = label.superview ?? insightView
        cardView.applyShadow()
        cardView.backgroundColor = UIColor(hex: "#A8E38F")
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor(hex: "#0B1E12").cgColor
        cardView.clipsToBounds = false

        cardView.viewWithTag(InsightCardStyle.bulbImageViewTag)?.removeFromSuperview()
        let imageView = UIImageView(image: UIImage(named: "Blub"))
        imageView.tag = InsightCardStyle.bulbImageViewTag
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.transform = CGAffineTransform(scaleX: -1, y: 1)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.insertSubview(imageView, at: 0)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            imageView.topAnchor.constraint(equalTo: cardView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            imageView.widthAnchor.constraint(equalToConstant: InsightCardStyle.imageWidth)
        ])

        cardView.constraints.forEach { constraint in
            if constraint.firstItem === label && constraint.firstAttribute == .leading {
                constraint.constant = InsightCardStyle.textLeading
            } else if constraint.secondItem === label && constraint.secondAttribute == .trailing {
                constraint.constant = InsightCardStyle.textTrailing
            }
        }

        label.font = MintFont.space(size: 14, weight: .medium)
        label.textColor = AppColors.textPrimary
        label.numberOfLines = 0
        label.removeCharacterSpacing()
        label.text = nil
    }

    private func showReportsOnboarding() { startOnboarding() }

    private func startOnboarding() {
        let overlay = OnboardingSpotlightView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.configure(totalSteps: onboardingSteps.count)
        overlay.onTap = { [weak self] in self?.advanceOnboarding() }
        view.addSubview(overlay)
        spotlightView = overlay

        currentOnboardingStep = 0

        overlay.alpha = 0
        UIView.animate(withDuration: 0.25) {
            overlay.alpha = 1
        } completion: { _ in
            self.showCurrentStep(animated: false)
        }
    }

    private func advanceOnboarding() {
        currentOnboardingStep += 1
        if currentOnboardingStep < onboardingSteps.count {
            showCurrentStep(animated: true)
        } else {
            finishOnboarding()
        }
    }

    private func showCurrentStep(animated: Bool) {
        guard currentOnboardingStep < onboardingSteps.count else { return }
        let step = onboardingSteps[currentOnboardingStep]

        let frameInView = step.view.convert(step.view.bounds, to: view)
        let screenHeight = view.bounds.height
        let topPadding: CGFloat = 60
        let bottomPadding: CGFloat = 60

        let isFullyVisible = frameInView.minY >= topPadding &&
            frameInView.maxY <= screenHeight - bottomPadding

        if isFullyVisible {
            spotlightView?.spotlight(
                on: step.view,
                title: step.title,
                message: step.message,
                stepIndex: currentOnboardingStep,
                tooltipBelow: step.tooltipBelow,
                animated: animated
            )
        } else {
            spotlightView?.isUserInteractionEnabled = false

            let frameInScroll = step.view.convert(step.view.bounds, to: MainScrollView)
            let idealOffset = frameInScroll.midY - (screenHeight / 2)
            let maxOffset = max(0, MainScrollView.contentSize.height - MainScrollView.bounds.height)
            var finalOffset = max(0, min(idealOffset, maxOffset))

            let viewBottomInContent = frameInScroll.maxY
            let visibleBottomAtOffset = finalOffset + screenHeight - bottomPadding
            if viewBottomInContent > visibleBottomAtOffset {
                finalOffset = min(viewBottomInContent - screenHeight + bottomPadding + 20, maxOffset)
            }

            MainScrollView.setContentOffset(CGPoint(x: 0, y: finalOffset), animated: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.spotlightView?.isUserInteractionEnabled = true
                self.spotlightView?.spotlight(
                    on: step.view,
                    title: step.title,
                    message: step.message,
                    stepIndex: self.currentOnboardingStep,
                    tooltipBelow: step.tooltipBelow,
                    animated: animated
                )
            }
        }
    }

    private func finishOnboarding() {
        UIView.animate(withDuration: 0.3, animations: {
            self.spotlightView?.alpha = 0
        }, completion: { _ in
            self.spotlightView?.removeFromSuperview()
            self.spotlightView = nil
            self.MainScrollView.setContentOffset(.zero, animated: true)
        })
    }

    @objc
    private func handleReportDataChange() {
        reloadReports()
    }

    private func reloadReports() {
        transactions = db.fetchTransactions()
        categories = db.fetchCategories()
        bills = db.fetchBills()
        recurringPayments = db.fetchRecurringPayments()

        buildData()
        loadInsights()

        SummaryCard.reloadData()
        CategoryBreakdownDataEntry.reloadData()
        CategoryBreakdown.reloadData()
        SubsAndBillsCard?.reloadData()
    }

    private func buildData() {
        let calendar = Calendar.current
        let reportReferenceDate = Date()

        let reportMonth = calendar.component(.month, from: reportReferenceDate)
        let reportYear = calendar.component(.year, from: reportReferenceDate)

        let currentMonthExpenseTransactions = expenseTransactions.filter {
            calendar.component(.month, from: $0.timestamp) == reportMonth &&
            calendar.component(.year, from: $0.timestamp) == reportYear
        }

        let dayTotals = currentMonthExpenseTransactions.reduce(into: [Int: Double]()) { partialResult, transaction in
            let components = calendar.dateComponents([.day], from: transaction.timestamp)
            guard let day = components.day else { return }
            partialResult[day, default: 0] += transaction.amount
        }

        dailyData = dayTotals
            .map { DailySpending(day: $0.key, amount: $0.value) }
            .sorted { $0.day < $1.day }

        let totalCurrentMonthExpense = currentMonthExpenseTransactions.reduce(0) { $0 + $1.amount }
        let isCurrentReportMonth = calendar.isDate(reportReferenceDate, equalTo: Date(), toGranularity: .month)
        let currentDaysDivisor = isCurrentReportMonth
            ? max(calendar.component(.day, from: Date()), 1)
            : (calendar.range(of: .day, in: .month, for: reportReferenceDate)?.count ?? 30)
        dailyAverage = totalCurrentMonthExpense / Double(currentDaysDivisor)

        if let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: reportReferenceDate) {
            let previousMonth = calendar.component(.month, from: previousMonthDate)
            let previousYear = calendar.component(.year, from: previousMonthDate)

            let previousDayTotals = expenseTransactions.reduce(into: [Int: Double]()) { partialResult, transaction in
                let components = calendar.dateComponents([.year, .month, .day], from: transaction.timestamp)
                guard components.month == previousMonth,
                      components.year == previousYear,
                      let day = components.day
                else { return }
                partialResult[day, default: 0] += transaction.amount
            }

            let previousTotal = previousDayTotals.values.reduce(0, +)
            let previousDaysInMonth = calendar.range(of: .day, in: .month, for: previousMonthDate)?.count ?? 30
            previousMonthAverage = previousTotal > 0
                ? previousTotal / Double(previousDaysInMonth)
                : nil
        } else {
            previousMonthAverage = nil
        }

        let categoryTotals = currentMonthExpenseTransactions.reduce(into: [UUID: Double]()) { partialResult, transaction in
            guard let categoryId = transaction.categoryId else { return }
            partialResult[categoryId, default: 0] += transaction.amount
        }
        let totalCategoryExpense = categoryTotals.values.reduce(0, +)

        categoryData = categories.compactMap { category in
            guard let spent = categoryTotals[category.id], spent > 0 else { return nil }

            let percent = totalCategoryExpense > 0
                ? Int((spent / totalCategoryExpense * 100).rounded())
                : 0

            return CategorySpending(
                name: category.name,
                icon: category.icon,
                color: UIColor(hex: category.color),
                amount: spent,
                percent: percent
            )
        }
        .sorted { lhs, rhs in
            if lhs.amount == rhs.amount {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.amount > rhs.amount
        }

        if categoryData.count > 4 {
            categoryData = Array(categoryData.prefix(4))
        }

        let eventDates = bills
            .filter { !$0.isPaid }
            .map(\.billDate) +
            activeRecurringExpenses.compactMap { nextRecurringEventDate(for: $0, onOrAfter: Date()) }

        let preferredReportDate: Date = {
            let sortedEventDates = eventDates.sorted()
            guard !sortedEventDates.isEmpty else { return Date() }
            return sortedEventDates.first(where: { $0 >= Date() }) ?? sortedEventDates.last ?? Date()
        }()

        let calendarMonth = calendar.component(.month, from: preferredReportDate)
        let calendarYear = calendar.component(.year, from: preferredReportDate)
        let monthDataSource = CalendarDataSource(year: calendarYear, month: calendarMonth)

        let unpaidBills = bills
            .filter { !$0.isPaid }
            .sorted { $0.billDate < $1.billDate }

        let nextUnpaidBill = unpaidBills.first(where: { $0.billDate >= preferredReportDate }) ?? unpaidBills.first

        let nextBillText: String
        if let nextUnpaidBill {
            let dateText = AppFormatters.shortBillDate.string(from: nextUnpaidBill.billDate)
            let amountText = String(format: "%.0f", nextUnpaidBill.amount)
            nextBillText = "\(dateText) • ₹\(amountText)"
        } else {
            nextBillText = "No upcoming bills"
        }

        subsBillsCalendarData = SubsBillsCalendarData(
            year: calendarYear,
            month: calendarMonth,
            title: monthDataSource.displayTitle,
            eventIcons: calendarEventIcons(
                unpaidBills: unpaidBills,
                subscriptions: activeRecurringExpenses,
                year: calendarYear,
                month: calendarMonth
            ),
            nextBillText: nextBillText
        )
    }

    private func calendarEventIcons(unpaidBills: [Bill],
                                    subscriptions: [RecurringPayment],
                                    year: Int,
                                    month: Int) -> [Int: String] {
        let calendar = Calendar.current
        var iconsByDay: [Int: String] = [:]

        for subscription in subscriptions {
            let iconName = normalizedCalendarIconName(subscription.icon, fallback: "creditcard.fill")
            let days = recurringEventDates(for: subscription, year: year, month: month)
                .map { calendar.component(.day, from: $0) }

            for day in days where iconsByDay[day] == nil {
                iconsByDay[day] = iconName
            }
        }

        for bill in unpaidBills {
            let components = calendar.dateComponents([.year, .month, .day], from: bill.billDate)
            guard components.year == year,
                  components.month == month,
                  let day = components.day
            else { continue }

            iconsByDay[day] = normalizedCalendarIconName(bill.icon, fallback: "doc.text.fill")
        }

        return iconsByDay
    }

    private func normalizedCalendarIconName(_ iconName: String?, fallback: String) -> String {
        guard let iconName, !iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return iconName
    }

    private func setupCollectionViews() {
        SummaryCard.dataSource = self
        SummaryCard.delegate = self
        SummaryCard.register(
            UINib(nibName: "SummaryCardCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "SummaryCard"
        )
        SummaryCard.collectionViewLayout = makeLayout(for: SummaryCard)
        SummaryCard.showsHorizontalScrollIndicator = false

        CategoryBreakdownDataEntry.dataSource = self
        CategoryBreakdownDataEntry.delegate = self
        CategoryBreakdownDataEntry.register(
            UINib(nibName: "CategoryCardNameCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "CategoryCardName"
        )
        CategoryBreakdownDataEntry.register(
            UINib(nibName: PlaceHolderCollectionViewCell.nibName, bundle: nil),
            forCellWithReuseIdentifier: PlaceHolderCollectionViewCell.reuseIdentifier
        )
        if let layout = CategoryBreakdownDataEntry.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .vertical
            layout.minimumLineSpacing = 4
            layout.minimumInteritemSpacing = 0
            layout.estimatedItemSize = .zero
        }
        CategoryBreakdownDataEntry.showsVerticalScrollIndicator = false

        CategoryBreakdown.dataSource = self
        CategoryBreakdown.delegate = self
        CategoryBreakdown.register(
            UINib(nibName: "CategoryBreakdownCardCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "CategoryBreakdown"
        )
        CategoryBreakdown.collectionViewLayout = makeLayout(for: CategoryBreakdown)
        CategoryBreakdown.showsHorizontalScrollIndicator = false

        if let subsAndBillsCard = SubsAndBillsCard {
            subsAndBillsCard.dataSource = self
            subsAndBillsCard.delegate = self
            subsAndBillsCard.register(
                UINib(nibName: "Subs&BillsCardCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: "SubsBillsCard"
            )
            subsAndBillsCard.collectionViewLayout = makeLayout(for: subsAndBillsCard)
            subsAndBillsCard.showsHorizontalScrollIndicator = false
        } else {
            assertionFailure("SubsAndBillsCard outlet is not connected in Main.storyboard")
        }
    }

    private func makeLayout(for collectionView: UICollectionView) -> UICollectionViewFlowLayout {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = collectionView.bounds.size
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = .horizontal
        return layout
    }

    private func updateCardLayouts() {
        let collectionViews = [SummaryCard, CategoryBreakdown, SubsAndBillsCard].compactMap { $0 }
        for collectionView in collectionViews {
            guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { continue }
            guard collectionView.bounds.size != .zero, layout.itemSize != collectionView.bounds.size else { continue }
            layout.itemSize = collectionView.bounds.size
            layout.invalidateLayout()
        }
    }

    private func loadInsights() {
        let requestPayload = makeInsightsRequest()
        let requestEnvelope = makeInsightsEnvelope(from: requestPayload)

        guard shouldRequestInsights(for: requestPayload) else {
            applyInsights(nil)
            return
        }

        let cachedResponse = cachedInsightsResponse(for: requestEnvelope)
        if let cachedResponse {
            applyInsights(cachedResponse)
        }

        insightTask?.cancel()
        insightTask = Task { [weak self] in
            guard let self else { return }

            let generatedResponse = await LocalInsightsService.shared.generateReportsInsights(for: requestEnvelope)
            guard !Task.isCancelled else { return }

            if self.hasUsableInsights(generatedResponse) {
                self.storeInsightsResponse(generatedResponse, for: requestEnvelope)
            } else {
                self.clearCachedInsightsResponse()
            }

            if self.hasUsableInsights(generatedResponse) || cachedResponse == nil {
                self.applyInsights(generatedResponse)
            }
        }
    }

    private func shouldRequestInsights(for requestPayload: ReportsInsightsPayload) -> Bool {
        requestPayload.summary.totalExpense > 0 ||
        requestPayload.summary.totalIncome > 0 ||
        requestPayload.category.totalExpense > 0 ||
        requestPayload.subsAndBills.unpaidBillsCount > 0 ||
        requestPayload.subsAndBills.activeSubscriptionCount > 0
    }

    private func makeInsightsRequest() -> ReportsInsightsPayload {
        let calendar = Calendar.current
        let today = Date()
        let monthFormatter = DateFormatter()
        monthFormatter.calendar = calendar
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "LLLL"

        let currentMonthTransactions = transactions.filter {
            calendar.isDate($0.timestamp, equalTo: today, toGranularity: .month)
        }
        let currentMonthExpenses = currentMonthTransactions.filter { $0.type == .expense }
        let currentMonthIncome = currentMonthTransactions.filter { $0.type == .income }
        let totalExpense = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        let totalIncome = currentMonthIncome.reduce(0) { $0 + $1.amount }
        let daysElapsed = max(calendar.component(.day, from: today), 1)
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        let highestSpendDay = dailyData.max { $0.amount < $1.amount }
        let budget = db.fetchCurrentBudget()?.allocatedBudget

        let categoryTotals = currentMonthExpenses.reduce(into: [UUID: Double]()) { partialResult, transaction in
            guard let categoryId = transaction.categoryId else { return }
            partialResult[categoryId, default: 0] += transaction.amount
        }
        let topCategories = categoryTotals
            .compactMap { categoryId, amount -> ReportsInsightsPayload.CategoryItem? in
                guard let category = categories.first(where: { $0.id == categoryId }) else { return nil }
                let sharePercent = totalExpense > 0
                    ? Int((amount / totalExpense * 100).rounded())
                    : 0
                return ReportsInsightsPayload.CategoryItem(
                    name: category.name,
                    amount: amount,
                    sharePercent: sharePercent,
                    budget: category.budget > 0 ? category.budget : nil
                )
            }
            .sorted { $0.amount > $1.amount }

        let startOfToday = calendar.startOfDay(for: today)
        let unpaidBills = bills
            .filter { !$0.isPaid }
            .sorted { $0.billDate < $1.billDate }
        let upcomingBills = unpaidBills.filter {
            calendar.startOfDay(for: $0.billDate) >= startOfToday
        }
        let nextBill = upcomingBills.first ?? unpaidBills.first
        let daysUntilNextBill = nextBill.flatMap {
            calendar.dateComponents(
                [.day],
                from: startOfToday,
                to: calendar.startOfDay(for: $0.billDate)
            ).day
        }

        let reportYear = calendar.component(.year, from: today)
        let reportMonth = calendar.component(.month, from: today)
        let activeSubscriptions = activeRecurringExpenses.sorted { $0.nextDate < $1.nextDate }
        let subscriptionsOccurringThisMonth = activeSubscriptions.filter {
            !recurringEventDates(for: $0, year: reportYear, month: reportMonth).isEmpty
        }

        return ReportsInsightsPayload(
            summary: .init(
                monthName: monthFormatter.string(from: today),
                year: calendar.component(.year, from: today),
                daysElapsed: daysElapsed,
                daysInMonth: daysInMonth,
                totalExpense: totalExpense,
                totalIncome: totalIncome,
                dailyAverage: dailyAverage ?? 0,
                previousMonthAverage: previousMonthAverage,
                transactionCount: currentMonthExpenses.count,
                highestSpendDay: highestSpendDay?.day,
                highestSpendDayAmount: highestSpendDay?.amount,
                budget: budget,
                remainingBudget: budget.map { $0 - totalExpense }
            ),
            category: .init(
                totalExpense: totalExpense,
                categoryCount: topCategories.count,
                topCategories: Array(topCategories.prefix(3))
            ),
            subsAndBills: .init(
                monthName: subsBillsCalendarData?.title ?? monthFormatter.string(from: today),
                unpaidBillsCount: unpaidBills.count,
                upcomingBillsTotal: upcomingBills.reduce(0) { $0 + $1.amount },
                nextBillName: nextBill?.name,
                nextBillAmount: nextBill?.amount,
                nextBillDueDate: nextBill.map { db.databaseDateOnlyString(from: $0.billDate) },
                daysUntilNextBill: daysUntilNextBill,
                activeSubscriptionCount: subscriptionsOccurringThisMonth.count,
                monthlySubscriptionTotal: subscriptionsOccurringThisMonth.reduce(0) { total, subscription in
                    total + (Double(recurringEventDates(for: subscription, year: reportYear, month: reportMonth).count) * subscription.amount)
                }
            )
        )
    }

    private func makeInsightsEnvelope(from request: ReportsInsightsPayload) -> ReportsInsightsEnvelope {
        ReportsInsightsEnvelope(
            payload: request,
            fields: ["summary", "category_highlight", "subs_and_bills"],
            forceRefresh: false
        )
    }

    private func applyInsights(_ response: ReportsInsightsResponse?) {
        updateInsight(view: summaryInsightVIew, label: summaryInsightLabel, text: response?.summary)
        updateInsight(view: categoryInsightView, label: categoryInsightLabel, text: response?.categoryHighlight)
        updateInsight(view: subsAndBillsInsightView, label: subsAndBillsInsightLabel, text: response?.subsAndBills)
    }

    private func updateInsight(view: UIView, label: UILabel, text: String?) {
        let cleanedText = sanitizeInsight(text)
        label.text = cleanedText
        view.isHidden = cleanedText.isEmpty
    }

    private func sanitizeInsight(_ text: String?) -> String {
        let cleanedText = text?
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ") ?? ""

        let lowercaseText = cleanedText.lowercased()
        let blockedPrefixes = [
            "could not",
            "no insight",
            "n/a",
            "none",
            "null"
        ]
        let blockedExactValues = [
            "home digest",
            "home_digest",
            "summary",
            "category highlight",
            "category_highlight",
            "subs and bills",
            "subs_and_bills",
            "goal insight",
            "goal_insight"
        ]

        if cleanedText.isEmpty ||
            blockedPrefixes.contains(where: { lowercaseText.hasPrefix($0) }) ||
            blockedExactValues.contains(lowercaseText) ||
            isLowValueInsight(lowercaseText)
        {
            return ""
        }

        return cleanedText
    }

    private func isLowValueInsight(_ lowercaseText: String) -> Bool {
        let obviousMarkers = [
            "spend is ",
            "spending is ",
            "spending stands at ",
            "peaked on day ",
            "leads spending at ",
            "upcoming unpaid bills currently add up to ",
            "active subscriptions total "
        ]

        if obviousMarkers.contains(where: { lowercaseText.contains($0) }) {
            return true
        }

        let dueDateOnlyMarkers = [
            " is due today.",
            " is due tomorrow.",
            " is due in "
        ]

        if dueDateOnlyMarkers.contains(where: { lowercaseText.contains($0) }) &&
            !lowercaseText.contains("set aside") &&
            !lowercaseText.contains("plan") &&
            !lowercaseText.contains("buffer") &&
            !lowercaseText.contains("keep")
        {
            return true
        }

        return false
    }

    private func cachedInsightsResponse(for envelope: ReportsInsightsEnvelope) -> ReportsInsightsResponse? {
        guard let defaultsKey = insightsCacheKey,
              let signatureKey = insightsCacheSignatureKey,
              let storedSignature = UserDefaults.standard.string(forKey: signatureKey),
              let currentSignature = encodedInsightsSignature(for: envelope),
              storedSignature == currentSignature,
              let data = UserDefaults.standard.data(forKey: defaultsKey)
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let response = try? decoder.decode(ReportsInsightsResponse.self, from: data),
              hasUsableInsights(response)
        else {
            clearCachedInsightsResponse()
            return nil
        }

        return response
    }

    private func storeInsightsResponse(_ response: ReportsInsightsResponse, for envelope: ReportsInsightsEnvelope) {
        guard let defaultsKey = insightsCacheKey,
              let signatureKey = insightsCacheSignatureKey,
              let signature = encodedInsightsSignature(for: envelope)
        else {
            return
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(response) else { return }

        UserDefaults.standard.set(data, forKey: defaultsKey)
        UserDefaults.standard.set(signature, forKey: signatureKey)
    }

    private var insightsCacheKey: String? {
        guard let userId = db.currentUserIdString else { return nil }
        return "reports_insights_response_\(userId)"
    }

    private var insightsCacheSignatureKey: String? {
        guard let userId = db.currentUserIdString else { return nil }
        return "reports_insights_signature_\(userId)"
    }

    private func encodedInsightsSignature(for envelope: ReportsInsightsEnvelope) -> String? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(envelope) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func hasUsableInsights(_ response: ReportsInsightsResponse) -> Bool {
        !sanitizeInsight(response.summary).isEmpty ||
        !sanitizeInsight(response.categoryHighlight).isEmpty ||
        !sanitizeInsight(response.subsAndBills).isEmpty
    }

    private func clearCachedInsightsResponse() {
        if let defaultsKey = insightsCacheKey {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
        if let signatureKey = insightsCacheSignatureKey {
            UserDefaults.standard.removeObject(forKey: signatureKey)
        }
    }

}

extension ReportsViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == CategoryBreakdownDataEntry {
            return max(categoryData.count, 1)
        }

        return 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == SummaryCard {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SummaryCard", for: indexPath) as! SummaryCardCollectionViewCell
            cell.configure(
                with: dailyData,
                currentAverage: dailyAverage,
                previousMonthAverage: previousMonthAverage
            )
            return cell
        }

        if collectionView == CategoryBreakdownDataEntry {
            if categoryData.isEmpty {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: PlaceHolderCollectionViewCell.reuseIdentifier,
                    for: indexPath
                ) as! PlaceHolderCollectionViewCell
                cell.configure(message: EmptyStateMessage.topCategories, sizeStyle: .listRow)
                return cell
            }

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCardName", for: indexPath) as! CategoryCardNameCollectionViewCell
            cell.configure(with: categoryData[indexPath.item])
            return cell
        }

        if collectionView == CategoryBreakdown {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryBreakdown", for: indexPath) as! CategoryBreakdownCardCollectionViewCell
            cell.configure(with: categoryData)
            return cell
        }

        if collectionView == SubsAndBillsCard {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SubsBillsCard", for: indexPath) as! Subs_BillsCardCollectionViewCell
            if let subsBillsCalendarData {
                cell.configure(with: subsBillsCalendarData)
            }
            return cell
        }
        return UICollectionViewCell()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard collectionView == CategoryBreakdownDataEntry else {
            return collectionView.bounds.size
        }

        let visibleRows = max(min(categoryData.count, 4), 1)
        let spacing: CGFloat = 4 * CGFloat(max(visibleRows - 1, 0))
        let height = floor((collectionView.bounds.height - spacing) / CGFloat(visibleRows))
        return CGSize(width: collectionView.bounds.width, height: max(height, 28))
    }
}
