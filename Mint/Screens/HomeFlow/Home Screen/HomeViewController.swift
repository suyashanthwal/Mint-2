
import UIKit
import CoreText
import SDWebImage

private struct HomeInsightsPayload: Codable {

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

    struct GoalItem: Codable {
        let name: String
        let target: Double
        let saved: Double
        let monthlyContribution: Double
    }

    let summary: SummarySection
    let category: CategorySection
    let subsAndBills: SubsAndBillsSection
    let goals: [GoalItem]
}

private struct HomeInsightsEnvelope: Codable {
    let payload: HomeInsightsPayload
    let fields: [String]
    let forceRefresh: Bool
}

private struct HomeInsightsResponse: Codable {
    let homeDigest: String?
}

class HomeViewController: UIViewController, UICollectionViewDelegate {
    private enum SegueIdentifier {
        static let summary = "HomeToSummary"
    }

    private let goalFallbackBackground = AppColors.sectionBackground
    private let goalFallbackSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 36, weight: .semibold)
    private let goalBaseGradientLayer = CAGradientLayer()
    private let goalFillGradientLayer = CAGradientLayer()

    private enum DashboardGoalBackgroundMode {
        case active
        case completed
        case empty
    }

    private enum HomeUpcomingItem {
        case bill(Bill)
        case subscription(RecurringPayment)
    }

    private enum EmptyStateMessage {
        static let recentTransactions = "Your recent transactions will be visible here."
        static let upcomingBills = "Your upcoming bills will be visible here."
    }

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var todaycardview: UIView!
    @IBOutlet weak var goalcardview: UIView!
    @IBOutlet weak var recentcardview: UIView!
    @IBOutlet weak var upcomingcardview: UIView!

    @IBOutlet private weak var dashboardLabel: UILabel?
    @IBOutlet weak var MonthlyView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var budgetAmountLabel: UILabel?
    @IBOutlet weak var monthlyRemainingLabel: UILabel?
    @IBOutlet weak var profileButton: UIButton?

    @IBOutlet private weak var confirmCardView: UIView!
    @IBOutlet private weak var confirmSectionContainerView: UIView!
    @IBOutlet private weak var transactionsCollectionView: UICollectionView!
    @IBOutlet private weak var billsCollectionView: UICollectionView!
    @IBOutlet weak var confirmCollectionView: UICollectionView!
    
    @IBOutlet weak var dailyAverage: UILabel!
    @IBOutlet private weak var dailyAverageTitleLabel: UILabel?
    @IBOutlet private weak var dailyAverageUnitLabel: UILabel?

    @IBOutlet weak var averageCardsView: UIView!
    @IBOutlet weak var goalsCardView: UIView!
    @IBOutlet private weak var savingGoalsTitleLabel: UILabel?
    @IBOutlet weak var GoalNameLabel: UILabel!
    @IBOutlet weak var SavedSoFarLabel: UILabel!
    @IBOutlet private weak var completedLabel: UILabel?
    @IBOutlet weak var goalImageView: UIImageView?
    @IBOutlet private weak var streakTitleLabel: UILabel?
    @IBOutlet weak var streakCountLabel: UILabel?
    @IBOutlet weak var streakCaptionLabel: UILabel?
    @IBOutlet weak var streakFireImageView: UIImageView?
    @IBOutlet weak var goalProgressContainerView: UIView?
    @IBOutlet private weak var upcomingBillsTitleLabel: UILabel?
    @IBOutlet private weak var confirmTransactionsTitleLabel: UILabel?
    @IBOutlet private weak var recentTransactionsTitleLabel: UILabel?
    
    @IBOutlet weak var insightImage: UIImageView?
    @IBOutlet weak var monthlyFlipButton: UIButton!
    @IBOutlet weak var goalsButton: UIButton!
    @IBOutlet weak var insightsLabel: UILabel!
    @IBOutlet weak var insightViewCard: UIView!
    private var hasCheckedOnboarding = false
    private var transactions: [Transaction] = []
    private var allTransactions: [Transaction] = []
    private var pendingTransactions: [BufferedTransaction] = []
    private var upcomingItems: [HomeUpcomingItem] = []
    private var allBills: [Bill] = []
    private var goals: [Goal] = []
    private var recurringPayments: [RecurringPayment] = []
    private var currentBudget: Budget?
    private var selectedGoalProgress: CGFloat = 0
    private var selectedGoalBackgroundMode: DashboardGoalBackgroundMode = .empty
    private var categories: [Category] = []
    private var goalImageProcessingTask: Task<Void, Never>?
    private let db = DatabaseManager.shared
    private static let insightsBaseURLDefaultsKey = "mint_insights_base_url"
    private var insightsBaseURL: URL? {
        if let override = UserDefaults.standard.string(forKey: Self.insightsBaseURLDefaultsKey),
           let url = sanitizedInsightsBaseURL(from: override) {
            return url
        }

        let configuredBaseURL = Bundle.main.object(forInfoDictionaryKey: "MintInsightsBaseURL") as? String
        return configuredBaseURL.flatMap(sanitizedInsightsBaseURL(from:))
    }
    private var insightsURL: URL? {
        insightsBaseURL?.appendingPathComponent("insights")
    }
    private var insightTask: URLSessionDataTask?
    private let contextMenuFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let actionFeedbackGenerator = UINotificationFeedbackGenerator()

    private var spotlightView: OnboardingSpotlightView?
    private var currentOnboardingStep = 0
    private var onboardingSteps: [OnboardingStep] = []

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        loadDataFromDatabase()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDashboardAppearance()

        setupConfirmCollectionView()
        setupTransactionsCollectionView()
        setupBillsCollectionView()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTransactionDataChange),
            name: .transactionDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBufferTransactionDataChange),
            name: .bufferTransactionDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSupportingDataChange),
            name: .categoryDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSupportingDataChange),
            name: .goalDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSupportingDataChange),
            name: .budgetDataDidChange,
            object: nil
        )
        
        loadDataFromDatabase()

        onboardingSteps = [
            OnboardingStep(
                view: MonthlyView,
                title: "Monthly Overview",
                message: "See your total spending for the month at a glance.",
                tooltipBelow: true
            ),
            OnboardingStep(
                view: todaycardview,
                title: "Daily Limit",
                message: "Track today's spending against your daily budget so you stay on track.",
                tooltipBelow: true
            ),
            OnboardingStep(
                view: goalsCardView,
                title: "Savings Goal",
                message: "Monitor your progress toward a specific savings target.",
                tooltipBelow: true
            ),
            OnboardingStep(
                view: upcomingcardview,
                title: "Upcoming Bills",
                message: "Bills due soon appear here so you're never caught off guard.",
                tooltipBelow: false
            ),
            OnboardingStep(
                view: recentcardview,
                title: "Recent Transactions",
                message: "Your latest spending activity, always one glance away.",
                tooltipBelow: false
            ),
        ]
    }

    @IBAction func goalSummaryToGoalPage(_ sender: Any) {
        switchToGoalsTab()
    }
    @IBAction func monthlyFlipButton(_ sender: Any) {
    }
    @IBAction func monthlyToSummaryButton(_ sender: Any) {
        performSegue(withIdentifier: SegueIdentifier.summary, sender: sender)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasCheckedOnboarding else { return }
        hasCheckedOnboarding = true

        if OnboardingHelper.shouldShow(key: OnboardingKeys.home) {
            showHomeOnboarding()
            OnboardingHelper.markSeen(key: OnboardingKeys.home)
        }
    }

    private func switchToGoalsTab() {
        guard let tabBarController,
              let viewControllers = tabBarController.viewControllers else { return }

        for (index, controller) in viewControllers.enumerated() {
            if let navigationController = controller as? UINavigationController,
               navigationController.viewControllers.first is GoalsViewController {
                navigationController.popToRootViewController(animated: false)
                tabBarController.selectedIndex = index
                return
            }

            if controller is GoalsViewController {
                tabBarController.selectedIndex = index
                return
            }
        }
    }

    deinit {
        goalImageProcessingTask?.cancel()
        insightTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    
    private func loadDataFromDatabase() {
        categories        = db.fetchCategories()
        allTransactions   = db.fetchTransactions()
        transactions      = db.fetchRecentTransactions(limit: 5)
        pendingTransactions = db.fetchBufferedTransactions()
        allBills          = db.fetchBills()
        recurringPayments = db.fetchRecurringPayments()
        upcomingItems     = buildUpcomingItemsForHome()
        goals             = db.fetchGoals()
        GoalImageStore.attachSavedImages(to: &goals)
        currentBudget     = db.fetchCurrentBudget()

        if isViewLoaded {
            updateHomeCollectionLayouts()
        }

        updateMonthlyOverview()
        updateDailyAverageCard()
        updateStreakCard()
        updateGoalCard()
        loadInsights()
        applyDashboardTypography()

        updateConfirmSectionVisibility()
        confirmCollectionView.reloadData()
        transactionsCollectionView.reloadData()
        billsCollectionView.reloadData()
    }

    private func buildUpcomingItemsForHome() -> [HomeUpcomingItem] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let billItems = allBills
            .filter { !$0.isPaid || $0.billDate >= startOfToday }
            .map(HomeUpcomingItem.bill)
        let subscriptionItems = recurringPayments
            .filter { $0.isActive && !$0.isIncome }
            .sorted { $0.nextDate < $1.nextDate }
            .map(HomeUpcomingItem.subscription)

        return (billItems + subscriptionItems).sorted { lhs, rhs in
            func dueDate(for item: HomeUpcomingItem) -> Date {
                switch item {
                case .bill(let bill):
                    return bill.billDate
                case .subscription(let subscription):
                    return subscription.nextDate
                }
            }

            func isPaidLike(for item: HomeUpcomingItem) -> Bool {
                switch item {
                case .bill(let bill):
                    return bill.isPaid
                case .subscription:
                    return false
                }
            }

            let lhsPaid = isPaidLike(for: lhs)
            let rhsPaid = isPaidLike(for: rhs)

            if lhsPaid != rhsPaid {
                return !lhsPaid && rhsPaid
            }

            return dueDate(for: lhs) < dueDate(for: rhs)
        }
    }

    @objc private func handleTransactionDataChange() {
        loadDataFromDatabase()
    }

    @objc private func handleBufferTransactionDataChange() {
        loadDataFromDatabase()
    }

    @objc private func handleSupportingDataChange() {
        loadDataFromDatabase()
    }

    private func updateConfirmSectionVisibility() {
        let isHidden = pendingTransactions.isEmpty
        confirmSectionContainerView.isHidden = isHidden
        confirmCollectionView.isHidden = isHidden
    }
    

    private func showHomeOnboarding() {
        startOnboarding()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        confirmCollectionView.collectionViewLayout.invalidateLayout()
        transactionsCollectionView.collectionViewLayout.invalidateLayout()
        billsCollectionView.collectionViewLayout.invalidateLayout()
        applyDashboardGradients()
        updateDashboardGoalBackground()
        updateGoalImageMask()
        renderGoalProgress()
    }

    private func startOnboarding() {
        let overlay = OnboardingSpotlightView(frame: view.bounds)
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

        let isLastStep = currentOnboardingStep == onboardingSteps.count - 1

        if isLastStep {
            spotlightView?.isUserInteractionEnabled = false

            let bottomOffset = CGPoint(x: 0, y: scrollView.contentSize.height - scrollView.bounds.height)

            UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
                self.scrollView.setContentOffset(bottomOffset, animated: false)
            }, completion: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.spotlightView?.isUserInteractionEnabled = true
                    self.spotlightView?.spotlight(
                        on: step.view,
                        title: step.title,
                        message: step.message,
                        stepIndex: self.currentOnboardingStep,
                        tooltipBelow: step.tooltipBelow,
                        animated: false
                    )
                }
            })
        } else {
            spotlightView?.spotlight(
                on: step.view,
                title: step.title,
                message: step.message,
                stepIndex: currentOnboardingStep,
                tooltipBelow: step.tooltipBelow,
                animated: animated
            )
        }
    }

    private func finishOnboarding() {
        UIView.animate(withDuration: 0.3, animations: {
            self.spotlightView?.alpha = 0
        }, completion: { _ in
            self.spotlightView?.removeFromSuperview()
            self.spotlightView = nil
            self.scrollView.setContentOffset(.zero, animated: true)
        })
    }

    private func updateMonthlyOverview() {
        let monthlyExpense = currentMonthExpenseTransactions().reduce(0) { $0 + $1.amount }
        let budgetAmount = currentBudget?.allocatedBudget ?? 0
        let remainingAmount = max(budgetAmount - monthlyExpense, 0)

        amountLabel.text = compactCurrency(monthlyExpense)
        budgetAmountLabel?.text = "/ \(compactCurrency(budgetAmount))"
        monthlyRemainingLabel?.text = budgetAmount > 0
            ? "you have \(compactShortCurrency(remainingAmount)) left"
            : "set a budget to track this month"
    }

    private func updateDailyAverageCard() {
        let calendar = Calendar.current
        let monthlyExpense = currentMonthExpenseTransactions().reduce(0) { $0 + $1.amount }
        let daysElapsed = max(calendar.component(.day, from: Date()), 1)
        let actualDailyAverage = monthlyExpense / Double(daysElapsed)

        dailyAverage.text = compactCurrency(actualDailyAverage)
    }

    private func updateStreakCard() {
        let streak = continuousUnderBudgetDays()
        streakCountLabel?.text = "\(streak)x"
        streakCaptionLabel?.text = streak == 1 ? "day under budget" : "days under budget"
    }

    private func updateGoalCard() {
        let mostCompletedActiveGoal = goals
            .filter { $0.isActiveGoal }
            .max { $0.progress < $1.progress }
        let latestCompletedGoal = goals
            .filter(\.isCompleted)
            .sorted { ($0.completedOn ?? .distantPast) > ($1.completedOn ?? .distantPast) }
            .first
        let displayedGoal = mostCompletedActiveGoal ?? latestCompletedGoal

        if let goal = displayedGoal {
            let progressPercent = Int(round(Double(goal.progress) * 100))
            selectedGoalProgress = CGFloat(goal.progress)
            selectedGoalBackgroundMode = goal.isCompleted ? .completed : .active
            GoalNameLabel.text = goal.name
            SavedSoFarLabel.attributedText = nil
            SavedSoFarLabel.text = "\(progressPercent)%"
            applyGoalImage(for: goal)
            updateDashboardGoalBackground()
            renderGoalProgress()
            return
        }

        selectedGoalProgress = 0
        selectedGoalBackgroundMode = .empty
        GoalNameLabel.text = "No goal yet"
        SavedSoFarLabel.attributedText = nil
        SavedSoFarLabel.text = "0%"
        applyGoalPlaceholderIcon(systemName: "target")
        updateDashboardGoalBackground()
        renderGoalProgress()
    }

    private func currentMonthExpenseTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return allTransactions.filter {
            $0.type == .expense &&
            calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month)
        }
    }

    private func todaysExpenseTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return allTransactions.filter {
            $0.type == .expense &&
            calendar.isDate($0.timestamp, inSameDayAs: now)
        }
    }

    private func currentDailyBudget() -> Double {
        guard let budgetAmount = currentBudget?.allocatedBudget, budgetAmount > 0 else { return 0 }
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        return budgetAmount / Double(daysInMonth)
    }

    private func expenseTotal(on day: Date) -> Double {
        let calendar = Calendar.current
        return allTransactions
            .filter { $0.type == .expense && calendar.isDate($0.timestamp, inSameDayAs: day) }
            .reduce(0) { $0 + $1.amount }
    }

    private func continuousUnderBudgetDays() -> Int {
        let dailyBudget = currentDailyBudget()
        guard dailyBudget > 0 else { return 0 }

        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        var day = calendar.startOfDay(for: Date())
        var count = 0

        while day >= startOfMonth {
            if expenseTotal(on: day) <= dailyBudget {
                count += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = previousDay
            } else {
                break
            }
        }

        return count
    }

    private func estimatedGoalAccelerationDays() -> Int? {
        guard let goal = goals
            .filter({ $0.isActiveGoal && $0.progress < 1 })
            .max(by: { $0.progress < $1.progress })
        else { return nil }

        let dailyBudget = currentDailyBudget()
        guard dailyBudget > 0 else { return nil }

        let calendar = Calendar.current
        let daysElapsed = max(calendar.component(.day, from: Date()), 1)
        let monthlyExpense = currentMonthExpenseTransactions().reduce(0) { $0 + $1.amount }
        let averageDailySavings = max(dailyBudget - (monthlyExpense / Double(daysElapsed)), 0)
        guard averageDailySavings > 0 else { return nil }

        let days = Int((goal.amountToGo / averageDailySavings).rounded(.down))
        return min(max(days, 1), 99)
    }

    private var expenseTransactions: [Transaction] {
        allTransactions.filter { $0.type == .expense }
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

    private func nextRecurringEventDate(for subscription: RecurringPayment, onOrAfter date: Date) -> Date? {
        let calendar = Calendar.current
        let searchStart = calendar.startOfDay(for: date)
        let startComponents = calendar.dateComponents([.year, .month], from: min(subscription.nextDate, searchStart))

        guard let startYear = startComponents.year,
              let startMonth = startComponents.month
        else { return subscription.nextDate }

        let monthStart = calendar.date(from: DateComponents(year: startYear, month: startMonth, day: 1)) ?? searchStart
        for offset in 0..<24 {
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: monthStart) else {
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

    private func loadInsights() {
        let requestPayload = makeInsightsPayload()
        let requestEnvelope = makeInsightsEnvelope(from: requestPayload)

        guard shouldRequestInsights(for: requestPayload), let insightsURL else {
            applyInsights(nil)
            return
        }

        let cachedResponse = cachedInsightsResponse(for: requestEnvelope)
        if let cachedResponse {
            applyInsights(cachedResponse)
        }

        insightTask?.cancel()

        var request = URLRequest(url: insightsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        guard let body = try? encoder.encode(requestEnvelope) else {
            applyInsights(nil)
            return
        }

        request.httpBody = body

        insightTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let nsError = error as NSError?, nsError.code == NSURLErrorCancelled {
                return
            }

            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data
            else {
                DispatchQueue.main.async {
                    if cachedResponse == nil {
                        self.applyInsights(nil)
                    }
                }
                return
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decodedResponse = try? decoder.decode(HomeInsightsResponse.self, from: data)

            DispatchQueue.main.async {
                if let decodedResponse, self.hasUsableInsights(decodedResponse) {
                    self.storeInsightsResponse(decodedResponse, for: requestEnvelope)
                } else {
                    self.clearCachedInsightsResponse()
                }

                if decodedResponse != nil || cachedResponse == nil {
                    self.applyInsights(decodedResponse)
                }
            }
        }

        insightTask?.resume()
    }

    private func shouldRequestInsights(for requestPayload: HomeInsightsPayload) -> Bool {
        requestPayload.summary.totalExpense > 0 ||
        requestPayload.summary.totalIncome > 0 ||
        requestPayload.category.totalExpense > 0 ||
        requestPayload.subsAndBills.unpaidBillsCount > 0 ||
        requestPayload.subsAndBills.activeSubscriptionCount > 0 ||
        !requestPayload.goals.isEmpty
    }

    private func makeInsightsPayload() -> HomeInsightsPayload {
        let calendar = Calendar.current
        let today = Date()
        let monthFormatter = DateFormatter()
        monthFormatter.calendar = calendar
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        monthFormatter.dateFormat = "LLLL"

        let currentMonthTransactions = allTransactions.filter {
            calendar.isDate($0.timestamp, equalTo: today, toGranularity: .month)
        }
        let currentMonthExpenses = currentMonthTransactions.filter { $0.type == .expense }
        let currentMonthIncome = currentMonthTransactions.filter { $0.type == .income }
        let totalExpense = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        let totalIncome = currentMonthIncome.reduce(0) { $0 + $1.amount }
        let daysElapsed = max(calendar.component(.day, from: today), 1)
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30

        let dayTotals = currentMonthExpenses.reduce(into: [Int: Double]()) { partialResult, transaction in
            let day = calendar.component(.day, from: transaction.timestamp)
            partialResult[day, default: 0] += transaction.amount
        }
        let highestSpendDay = dayTotals.max { $0.value < $1.value }

        let previousMonthAverage: Double? = {
            guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: today) else {
                return nil
            }

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
            guard previousTotal > 0 else { return nil }
            return previousTotal / Double(previousDaysInMonth)
        }()

        let categoryTotals = currentMonthExpenses.reduce(into: [UUID: Double]()) { partialResult, transaction in
            guard let categoryId = transaction.categoryId else { return }
            partialResult[categoryId, default: 0] += transaction.amount
        }
        let topCategories = categoryTotals
            .compactMap { categoryId, amount -> HomeInsightsPayload.CategoryItem? in
                guard let category = categories.first(where: { $0.id == categoryId }) else { return nil }
                let sharePercent = totalExpense > 0
                    ? Int((amount / totalExpense * 100).rounded())
                    : 0
                return HomeInsightsPayload.CategoryItem(
                    name: category.name,
                    amount: amount,
                    sharePercent: sharePercent,
                    budget: category.budget > 0 ? category.budget : nil
                )
            }
            .sorted { $0.amount > $1.amount }

        let startOfToday = calendar.startOfDay(for: today)
        let unpaidBills = allBills
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
        let subscriptionsOccurringThisMonth = activeRecurringExpenses.filter {
            !recurringEventDates(for: $0, year: reportYear, month: reportMonth).isEmpty
        }

        let insightGoals = goals
            .filter(\.isActiveGoal)
            .sorted { $0.progress > $1.progress }
            .map {
                HomeInsightsPayload.GoalItem(
                    name: $0.name,
                    target: $0.targetAmount,
                    saved: $0.currentlySaved,
                    monthlyContribution: $0.monthlyGoal
                )
            }

        return HomeInsightsPayload(
            summary: .init(
                monthName: monthFormatter.string(from: today),
                year: calendar.component(.year, from: today),
                daysElapsed: daysElapsed,
                daysInMonth: daysInMonth,
                totalExpense: totalExpense,
                totalIncome: totalIncome,
                dailyAverage: totalExpense / Double(daysElapsed),
                previousMonthAverage: previousMonthAverage,
                transactionCount: currentMonthExpenses.count,
                highestSpendDay: highestSpendDay?.key,
                highestSpendDayAmount: highestSpendDay?.value,
                budget: currentBudget?.allocatedBudget,
                remainingBudget: currentBudget.map { $0.allocatedBudget - totalExpense }
            ),
            category: .init(
                totalExpense: totalExpense,
                categoryCount: topCategories.count,
                topCategories: Array(topCategories.prefix(3))
            ),
            subsAndBills: .init(
                monthName: monthFormatter.string(from: today),
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
            ),
            goals: insightGoals
        )
    }

    private func makeInsightsEnvelope(from payload: HomeInsightsPayload) -> HomeInsightsEnvelope {
        HomeInsightsEnvelope(
            payload: payload,
            fields: ["home_digest"],
            forceRefresh: false
        )
    }

    private func applyInsights(_ response: HomeInsightsResponse?) {
        let cleanedText = sanitizeInsight(response?.homeDigest)
        insightsLabel?.text = cleanedText
//        insightViewCard?.isHidden = cleanedText.isEmpty
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

        if cleanedText.isEmpty ||
            blockedPrefixes.contains(where: { lowercaseText.hasPrefix($0) }) ||
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
            "active subscriptions total ",
            "your total expense",
            "you have spent",
            "you spent a total",
            "total spending for",
            "goal is % complete",
            "you have saved",
            "subscriptions cost",
            "bills total"
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
            !lowercaseText.contains("transfer")
        {
            return true
        }

        return false
    }

    private func cachedInsightsResponse(for envelope: HomeInsightsEnvelope) -> HomeInsightsResponse? {
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
        guard let response = try? decoder.decode(HomeInsightsResponse.self, from: data),
              hasUsableInsights(response)
        else {
            clearCachedInsightsResponse()
            return nil
        }

        return response
    }

    private func storeInsightsResponse(_ response: HomeInsightsResponse, for envelope: HomeInsightsEnvelope) {
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
        return "home_insights_response_\(userId)"
    }

    private var insightsCacheSignatureKey: String? {
        guard let userId = db.currentUserIdString else { return nil }
        return "home_insights_signature_\(userId)"
    }

    private func encodedInsightsSignature(for envelope: HomeInsightsEnvelope) -> String? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(envelope) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func hasUsableInsights(_ response: HomeInsightsResponse) -> Bool {
        !sanitizeInsight(response.homeDigest).isEmpty
    }

    private func clearCachedInsightsResponse() {
        if let defaultsKey = insightsCacheKey {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
        if let signatureKey = insightsCacheSignatureKey {
            UserDefaults.standard.removeObject(forKey: signatureKey)
        }
    }

    private func sanitizedInsightsBaseURL(from rawValue: String) -> URL? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }
        return URL(string: trimmedValue)?.standardized
    }

    private func toggleBillPaymentState(for billId: UUID) {
        guard let bill = allBills.first(where: { $0.id == billId }) else { return }

        let nextPaidState = !bill.isPaid
        db.updateBillPaymentStatus(id: billId, isPaid: nextPaidState)
        db.removeBillPaymentTransaction(billId: billId)

        if nextPaidState {
            _ = db.insertExpenseTransaction(
                name: bill.name,
                amount: bill.amount,
                timestamp: Date(),
                categoryId: bill.categoryId,
                status: true,
                expenseType: "bill",
                source: .manual,
                note: db.billPaymentNote(for: billId)
            )
        }

        if nextPaidState {
            BillSubscriptionReminderManager.shared.cancelReminder(forBillId: billId)
        } else if let refreshedBill = db.fetchBill(id: billId) {
            BillSubscriptionReminderManager.shared.scheduleReminder(for: refreshedBill)
        }

        db.resetMonthlyExpense()
        actionFeedbackGenerator.notificationOccurred(.success)
        NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
        NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
        loadDataFromDatabase()
    }

    private func confirmBufferedTransaction(id: UUID) {
        guard db.confirmBufferedTransaction(id: id) else { return }

        db.resetMonthlyExpense()
        actionFeedbackGenerator.notificationOccurred(.success)
        NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
        NotificationCenter.default.post(name: .bufferTransactionDataDidChange, object: nil)
        loadDataFromDatabase()
    }

    private func discardBufferedTransaction(id: UUID) {
        guard DatabaseManager.shared.discardBufferedTransaction(id: id) else { return }

        actionFeedbackGenerator.notificationOccurred(.warning)
        NotificationCenter.default.post(name: .bufferTransactionDataDidChange, object: nil)
        loadDataFromDatabase()
    }

    private func promptDeleteTransaction(_ transaction: Transaction) {
        let alert = UIAlertController(
            title: "Delete \"\(transaction.name)\"?",
            message: "This will remove the transaction and refresh your totals.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteTransaction(transaction)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func deleteTransaction(_ transaction: Transaction) {
        guard db.deleteTransaction(id: transaction.id) else { return }

        actionFeedbackGenerator.notificationOccurred(.success)
        NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
    }

    private func presentEditTransaction(_ transaction: Transaction) {
        guard let nav = storyboard?.instantiateViewController(withIdentifier: "EditTransactionNav") as? UINavigationController,
              let editViewController = nav.viewControllers.first as? EditTransactionViewController
        else { return }

        editViewController.transaction = transaction
        editViewController.onTransactionUpdated = { [weak self] in
            self?.loadDataFromDatabase()
        }
        present(nav, animated: true)
    }

    private func setupConfirmCollectionView() {
        confirmCardView.backgroundColor = AppColors.card
        confirmCardView.layer.cornerRadius = 14
        confirmCardView.layer.masksToBounds = false

        confirmCollectionView.register(
            UINib(nibName: "ConfirmationTransactionsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "ConfirmTransactionCell"
        )
        confirmCollectionView.collectionViewLayout = generateConfirmLayout()
        confirmCollectionView.isScrollEnabled = false
        confirmCollectionView.backgroundColor = .white
        confirmCollectionView.layer.cornerRadius = 14
        confirmCollectionView.layer.masksToBounds = true
        confirmCollectionView.clipsToBounds = true
        confirmCollectionView.showsVerticalScrollIndicator = false
        confirmCollectionView.dataSource = self
        confirmCollectionView.delegate = self
    }
    private func setupTransactionsCollectionView() {
        registerPlaceholderCell(for: transactionsCollectionView)
        transactionsCollectionView.register(
            UINib(nibName: "RecentTransactionsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "RecentTransactionCell"
        )
        transactionsCollectionView.collectionViewLayout = generateVerticalLayout()
        transactionsCollectionView.isScrollEnabled = false
        transactionsCollectionView.layer.cornerRadius = 14
        transactionsCollectionView.layer.masksToBounds = true
        transactionsCollectionView.clipsToBounds = true
        transactionsCollectionView.backgroundColor = .white
        transactionsCollectionView.dataSource = self
        transactionsCollectionView.delegate   = self
    }

    private func setupBillsCollectionView() {
        registerPlaceholderCell(for: billsCollectionView)
        billsCollectionView.register(
            UINib(nibName: "UpcomingBillsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "UpcomingBillsCell"
        )
        billsCollectionView.collectionViewLayout = generateHorizontalLayout()
        billsCollectionView.backgroundColor = .clear
        billsCollectionView.showsHorizontalScrollIndicator = false
        billsCollectionView.showsVerticalScrollIndicator = false
        billsCollectionView.alwaysBounceVertical = false
        billsCollectionView.clipsToBounds = false
        billsCollectionView.layer.masksToBounds = false
        billsCollectionView.dataSource = self
        billsCollectionView.delegate   = self
        billsCollectionView.bounces = false
        billsCollectionView.isDirectionalLockEnabled = true
    }

    private func registerPlaceholderCell(for collectionView: UICollectionView) {
        collectionView.register(
            UINib(nibName: PlaceHolderCollectionViewCell.nibName, bundle: nil),
            forCellWithReuseIdentifier: PlaceHolderCollectionViewCell.reuseIdentifier
        )
    }

    private func updateHomeCollectionLayouts() {
        confirmCollectionView.collectionViewLayout = generateConfirmLayout()
        transactionsCollectionView.collectionViewLayout = generateVerticalLayout()
        billsCollectionView.collectionViewLayout = generateHorizontalLayout()
    }

    private func generateVerticalLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: transactions.isEmpty ? .absolute(60) : .estimated(64)
        )
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 1
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func generateConfirmLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(64)
        )
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 1
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func generateHorizontalLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: upcomingItems.isEmpty ? .fractionalWidth(1.0) : .absolute(110),
            heightDimension: upcomingItems.isEmpty ? .fractionalHeight(1.0) : .absolute(185)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = upcomingItems.isEmpty ? .none : .continuous
        section.interGroupSpacing = upcomingItems.isEmpty ? 0 : 20
        section.contentInsets = .zero

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func isShowingPlaceholder(in collectionView: UICollectionView) -> Bool {
        if collectionView == billsCollectionView {
            return upcomingItems.isEmpty
        } else {
            return transactions.isEmpty
        }
    }

    private func placeholderMessage(for collectionView: UICollectionView) -> String {
        if collectionView == billsCollectionView {
            return EmptyStateMessage.upcomingBills
        } else {
            return EmptyStateMessage.recentTransactions
        }
    }

    private func dequeuePlaceholderCell(
        in collectionView: UICollectionView,
        for indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PlaceHolderCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! PlaceHolderCollectionViewCell
        let sizeStyle: PlaceHolderCollectionViewCell.SizeStyle =
            collectionView == billsCollectionView ? .compact : .listRow
        cell.configure(
            message: placeholderMessage(for: collectionView),
            sizeStyle: sizeStyle
        )
        return cell
    }

}

extension HomeViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView == confirmCollectionView {
            return pendingTransactions.count
        } else if collectionView == billsCollectionView {
            return max(upcomingItems.count, 1)
        } else {
            return max(min(transactions.count, 5), 1)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        if isShowingPlaceholder(in: collectionView) {
            return dequeuePlaceholderCell(in: collectionView, for: indexPath)
        }

        if collectionView == confirmCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "ConfirmTransactionCell",
                for: indexPath
            ) as! ConfirmationTransactionsCollectionViewCell
            let bufferedTransaction = pendingTransactions[indexPath.row]
            cell.configureCell(with: bufferedTransaction, categories: categories)
            cell.onApprove = { [weak self] in
                self?.confirmBufferedTransaction(id: bufferedTransaction.id)
            }
            cell.onDiscard = { [weak self] in
                self?.discardBufferedTransaction(id: bufferedTransaction.id)
            }
            return cell

        } else if collectionView == billsCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "UpcomingBillsCell",
                for: indexPath
            ) as! UpcomingBillsCollectionViewCell
            let isFirst = indexPath.item == 0
            let isLast = indexPath.item == upcomingItems.count - 1
            switch upcomingItems[indexPath.row] {
            case .bill(let bill):
                cell.configureCell(with: bill, isFirst: isFirst, isLast: isLast)
            case .subscription(let subscription):
                cell.configureCell(with: subscription, isFirst: isFirst, isLast: isLast)
            }
            return cell

        } else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "RecentTransactionCell",
                for: indexPath
            ) as! RecentTransactionsCollectionViewCell
            cell.configureCell(
                with: transactions[indexPath.row],
                categories: categories
            )
            return cell
        }
    }
}

extension HomeViewController {
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        collectionView.superview?.bringSubviewToFront(collectionView)
        view.bringSubviewToFront(scrollView)
        cell.layer.zPosition = 1000
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        cell.layer.zPosition = 0
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        if collectionView == transactionsCollectionView {
            guard !transactions.isEmpty else { return nil }
            let transaction = transactions[indexPath.item]
            contextMenuFeedbackGenerator.prepare()
            contextMenuFeedbackGenerator.impactOccurred()

            return UIContextMenuConfiguration(identifier: transaction.id.uuidString as NSString, previewProvider: nil) { [weak self] _ in
                let editAction = UIAction(
                    title: "Edit",
                    image: UIImage(systemName: "square.and.pencil")
                ) { _ in
                    self?.presentEditTransaction(transaction)
                }

                let deleteAction = UIAction(
                    title: "Delete",
                    image: UIImage(systemName: "trash"),
                    attributes: .destructive
                ) { _ in
                    self?.promptDeleteTransaction(transaction)
                }

                return UIMenu(title: transaction.name, children: [editAction, deleteAction])
            }
        }

        if collectionView == billsCollectionView {
            guard !upcomingItems.isEmpty else { return nil }
            guard case .bill(let bill) = upcomingItems[indexPath.item] else { return nil }
            contextMenuFeedbackGenerator.prepare()
            contextMenuFeedbackGenerator.impactOccurred()

            return UIContextMenuConfiguration(identifier: bill.id.uuidString as NSString, previewProvider: nil) { [weak self] _ in
                let title = bill.isPaid ? "Mark as Not Paid" : "Mark as Paid"
                let imageName = bill.isPaid ? "arrow.uturn.backward.circle" : "checkmark.circle"

                let toggleAction = UIAction(title: title, image: UIImage(systemName: imageName)) { _ in
                    self?.toggleBillPaymentState(for: bill.id)
                }

                return UIMenu(title: bill.name, children: [toggleAction])
            }
        }

        return nil
    }
}

private extension HomeViewController {
    func setupDashboardAppearance() {
        view.backgroundColor = AppColors.background
        scrollView.backgroundColor = AppColors.background
        scrollView.indicatorStyle = .white
        clearContainerBackgrounds(in: view)
        applyUpperLayoutSizing()
        applySectionTitleSpacing()
        insightImage!.transform = CGAffineTransform(scaleX: -1, y: 1)

        styleLabels(in: view, color: AppColors.textPrimary)
        styleLabels(in: goalcardview, color: .black)
        styleLabels(in: goalsCardView, color: AppColors.textPrimary)
        [budgetAmountLabel, monthlyRemainingLabel].forEach {
            $0?.textColor = AppColors.textSecondary
        }
        styleCard(MonthlyView, cornerRadius: 14)
        styleCard(averageCardsView, cornerRadius: 14, borderColor: AppColors.cardBorder)
        styleCard(goalcardview, cornerRadius: 14, fillColor: AppColors.orange)
        styleCard(goalsCardView, cornerRadius: 14)
//        styleCard(insightViewCard, cornerRadius: 14)
        insightViewCard.applyShadow()
        insightViewCard.backgroundColor = UIColor(hex: "#9FE48D")
        insightViewCard.layer.borderWidth = 1
        insightViewCard.layer.borderColor = UIColor(hex: "#0B1E12")
            .cgColor
        insightViewCard.isHidden = false
//        insightsLabel.text = nil

        MonthlyView.clipsToBounds = true
        goalsCardView.clipsToBounds = true
        upcomingcardview.clipsToBounds = false
        upcomingcardview.layer.masksToBounds = false
        recentcardview.clipsToBounds = false
        recentcardview.layer.masksToBounds = false
        confirmSectionContainerView.clipsToBounds = false
        confirmSectionContainerView.layer.masksToBounds = false
        averageCardsView.backgroundColor = AppColors.card
        goalcardview.backgroundColor = AppColors.orange
        configureDashboardGoalBackground()
        applyDashboardTypography()

        goalImageView?.contentMode = .scaleAspectFit
        goalImageView?.clipsToBounds = true
        goalProgressContainerView?.backgroundColor = .clear
        goalProgressContainerView?.layer.cornerRadius = (goalProgressContainerView?.bounds.width ?? 100) / 2
        goalProgressContainerView?.clipsToBounds = false
        goalProgressContainerView?.isHidden = false
        loadFireAnimation()
        profileButton?.backgroundColor = AppColors.textPrimary
        profileButton?.tintColor = AppColors.background
        profileButton?.layer.cornerRadius = 19
        profileButton?.clipsToBounds = true
        profileButton?.setImage(UIImage(systemName: "person.crop.circle"), for: .normal)
        profileButton?.addTarget(self, action: #selector(showProfile), for: .touchUpInside)
    }

    func applyDashboardGradients() {
        MonthlyView.applyGradient(
            colors: [
                UIColor(hex: "#641AEF").cgColor,
                UIColor(hex: "#9428FF").cgColor
            ],
            name: "monthlyGradient"
        )
    }

    func loadFireAnimation() {
        streakFireImageView?.contentMode = .scaleAspectFit
        streakFireImageView?.backgroundColor = .clear
        streakFireImageView?.image = nil

        guard let gifURL = Bundle.main.url(forResource: "fire", withExtension: "gif")
            ?? Bundle.main.url(forResource: "streak", withExtension: "gif") else {
            streakFireImageView?.image = UIImage(systemName: "flame.fill")
            streakFireImageView?.tintColor = AppColors.error
            return
        }

        streakFireImageView?.sd_setImage(with: gifURL, placeholderImage: nil, options: [.continueInBackground])
    }

    func configureDashboardGoalBackground() {
        goalBaseGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        goalBaseGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        goalBaseGradientLayer.locations = [0.0, 0.58, 1.0]

        goalFillGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        goalFillGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        goalFillGradientLayer.locations = [0.0, 1.0]

        if goalBaseGradientLayer.superlayer == nil {
            goalsCardView.layer.insertSublayer(goalBaseGradientLayer, at: 0)
        }
        if goalFillGradientLayer.superlayer == nil {
            goalsCardView.layer.insertSublayer(goalFillGradientLayer, above: goalBaseGradientLayer)
        }
    }

    func updateDashboardGoalBackground() {
        let bounds = goalsCardView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let clampedProgress = max(0, min(selectedGoalProgress, 1))
        let softenedProgress = max(0, clampedProgress - 0.03)

        goalBaseGradientLayer.frame = bounds
        goalFillGradientLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width * clampedProgress,
            height: bounds.height
        )

        switch selectedGoalBackgroundMode {
        case .active:
            goalBaseGradientLayer.colors = [
                UIColor(hex: "#1F4F23").withAlphaComponent(0.40).cgColor,
                UIColor(hex: "#2A602B").withAlphaComponent(0.18).cgColor,
                UIColor(hex: "#265928").withAlphaComponent(0.0).cgColor
            ]
            goalFillGradientLayer.colors = [
                UIColor(hex: "#2E732C").cgColor,
                UIColor(hex: "#4A9437").cgColor
            ]
            goalBaseGradientLayer.opacity = Float(min(0.45, softenedProgress * 0.55))
            goalFillGradientLayer.opacity = clampedProgress > 0.001 ? 1 : 0

        case .completed:
            goalBaseGradientLayer.colors = [
                UIColor(hex: "#245723").withAlphaComponent(0.48).cgColor,
                UIColor(hex: "#326B2D").withAlphaComponent(0.22).cgColor,
                UIColor(hex: "#2E642A").withAlphaComponent(0.02).cgColor
            ]
            goalFillGradientLayer.colors = [
                UIColor(hex: "#357E2F").cgColor,
                UIColor(hex: "#53A13D").cgColor
            ]
            goalBaseGradientLayer.opacity = Float(max(0.16, min(0.55, clampedProgress * 0.6)))
            goalFillGradientLayer.opacity = clampedProgress > 0.001 ? 1 : 0

        case .empty:
            goalBaseGradientLayer.colors = [
                UIColor(hex: "#1F4F23").withAlphaComponent(0.40).cgColor,
                UIColor(hex: "#2A602B").withAlphaComponent(0.18).cgColor,
                UIColor(hex: "#265928").withAlphaComponent(0.0).cgColor
            ]
            goalFillGradientLayer.colors = [
                UIColor(hex: "#2E732C").cgColor,
                UIColor(hex: "#4A9437").cgColor
            ]
            goalBaseGradientLayer.opacity = 0
            goalFillGradientLayer.opacity = 0
        }
    }

    func renderGoalProgress() {
        guard let container = goalProgressContainerView, !container.isHidden, container.bounds.width > 0 else { return }
        container.layer.cornerRadius = min(container.bounds.width, container.bounds.height) / 2

        container.layer.sublayers?
            .filter { $0.name == "goalProgressTrack" || $0.name == "goalProgressRing" }
            .forEach { $0.removeFromSuperlayer() }

        let lineWidth: CGFloat = 4
        let center = CGPoint(x: container.bounds.midX, y: container.bounds.midY)
        let radius = (min(container.bounds.width, container.bounds.height) - lineWidth) / 2
        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: (.pi * 2) - (.pi / 2),
            clockwise: true
        )

        let track = CAShapeLayer()
        track.name = "goalProgressTrack"
        track.path = path.cgPath
        track.fillColor = UIColor.clear.cgColor
        track.strokeColor = UIColor(hex: "#BFE9BA").withAlphaComponent(0.82).cgColor
        track.lineWidth = lineWidth

        let ring = CAShapeLayer()
        ring.name = "goalProgressRing"
        ring.path = path.cgPath
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = UIColor(hex: "#2AD66F").cgColor
        ring.lineWidth = lineWidth
        ring.lineCap = .butt
        ring.strokeEnd = min(max(selectedGoalProgress, 0), 1)

        container.layer.addSublayer(track)
        container.layer.addSublayer(ring)
        if let goalImageView {
            container.bringSubviewToFront(goalImageView)
        }
    }

    func applyGoalImage(for goal: Goal) {
        goalImageProcessingTask?.cancel()

        if let loadedImage = GoalImageStore.loadSavedImage(for: goal) {
            goalImageView?.image = loadedImage.image
            goalImageView?.contentMode = .scaleAspectFill
            goalImageView?.tintColor = nil
            goalImageView?.backgroundColor = .clear
            goalImageProcessingTask = GoalImageStore.migrateLegacyImageToSubjectOnlyIfNeeded(
                loadedImage,
                for: goal.id
            ) { [weak self] processedImage in
                self?.goalImageView?.image = processedImage
                self?.goalImageView?.tintColor = nil
                self?.goalImageView?.backgroundColor = .clear
            }
        } else if let imageName = goal.imageName, let image = UIImage(named: imageName) {
            goalImageView?.image = image
            goalImageView?.contentMode = .scaleAspectFill
            goalImageView?.tintColor = nil
            goalImageView?.backgroundColor = .clear
        } else {
            applyGoalPlaceholderIcon(systemName: goal.iconName)
        }
        updateGoalImageMask()
    }

    private func applyGoalPlaceholderIcon(systemName: String) {
        goalImageView?.image = UIImage(systemName: systemName)?
            .applyingSymbolConfiguration(goalFallbackSymbolConfiguration)
        goalImageView?.contentMode = .center
        goalImageView?.tintColor = AppColors.textPrimary
        goalImageView?.backgroundColor = .clear
    }

    func styleLabels(in rootView: UIView?, color: UIColor) {
        guard let rootView else { return }
        for subview in rootView.subviews {
            if let label = subview as? UILabel {
                label.textColor = color
            }
            styleLabels(in: subview, color: color)
        }
    }

    func clearContainerBackgrounds(in rootView: UIView) {
        for subview in rootView.subviews {
            if !(subview is UILabel),
               !(subview is UIImageView),
               !(subview is UIControl),
               !(subview is UICollectionView) {
                subview.backgroundColor = .clear
            }
            clearContainerBackgrounds(in: subview)
        }
    }

    func styleCard(
        _ cardView: UIView?,
        cornerRadius: CGFloat,
        fillColor: UIColor? = nil,
        borderColor: UIColor? = nil
    ) {
        guard let cardView else { return }
        cardView.backgroundColor = fillColor ?? AppColors.card
        cardView.layer.cornerRadius = cornerRadius
        cardView.layer.masksToBounds = true
        cardView.layer.borderWidth = borderColor == nil ? 0 : 1
        cardView.layer.borderColor = borderColor?.cgColor
    }

    func applyUpperLayoutSizing() {
        setHeightConstraint(on: MonthlyView.superview, to: 160)
        setHeightConstraint(on: averageCardsView.superview?.superview, to: 115)
        setHeightConstraint(on: goalsCardView.superview, to: 160)

        if let cardsStack = MonthlyView.superview?.superview as? UIStackView {
            cardsStack.spacing = 19
        }
    }

    func applySectionTitleSpacing() {
        let titleLabels = [
            upcomingBillsTitleLabel,
            confirmTransactionsTitleLabel,
            recentTransactionsTitleLabel
        ]

        titleLabels.forEach { titleLabel in
            guard let titleStack = titleLabel?.superview,
                  let headerView = titleStack.superview,
                  let sectionStack = headerView.superview as? UIStackView else { return }

            sectionStack.spacing = 12
            setHeightConstraint(on: headerView, to: 20)
        }

        setTopConstraint(on: billsCollectionView, to: 0)
        setTopConstraint(on: confirmCollectionView, to: 0)
        setTopConstraint(on: transactionsCollectionView, to: 0)
    }

    func applyDashboardTypography() {
        applyBaseTypography(in: view)
        let sectionHeadingFont = MintFont.space(size: 16, weight: .bold)

        dashboardLabel?.font = MintFont.space(size: 25, weight: .bold)
        dashboardLabel?.textColor = AppColors.textPrimary
        dashboardLabel?.removeCharacterSpacing()

        titleLabel.font = sectionHeadingFont
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.removeCharacterSpacing()

        amountLabel.font = MintFont.space(size: 38, weight: .heavy)
        amountLabel.textColor = AppColors.textPrimary
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.78
        amountLabel.removeCharacterSpacing()

        budgetAmountLabel?.font = MintFont.space(size: 24, weight: .heavy)
        budgetAmountLabel?.textColor = AppColors.textPrimary.withAlphaComponent(0.86)
        budgetAmountLabel?.removeCharacterSpacing()

        monthlyRemainingLabel?.font = MintFont.space(size: 16, weight: .medium)
        monthlyRemainingLabel?.textColor = AppColors.textPrimary.withAlphaComponent(0.9)
        monthlyRemainingLabel?.removeCharacterSpacing()

        dailyAverageTitleLabel?.font = sectionHeadingFont
        dailyAverageTitleLabel?.textColor = AppColors.textPrimary
        dailyAverageTitleLabel?.removeCharacterSpacing()

        dailyAverage.font = MintFont.space(size: 32, weight: .heavy)
        dailyAverage.textColor = AppColors.textPrimary
        dailyAverageUnitLabel?.font = MintFont.space(size: 11, weight: .bold)
        dailyAverageUnitLabel?.textColor = AppColors.textSecondary
        dailyAverage.removeCharacterSpacing()
        dailyAverageUnitLabel?.removeCharacterSpacing()

        streakTitleLabel?.font = sectionHeadingFont
        streakTitleLabel?.textColor = .black
        streakCountLabel?.font = MintFont.space(size: 24, weight: .heavy)
        streakCountLabel?.textColor = .black
        streakCaptionLabel?.font = MintFont.space(size: 14, weight: .bold)
        streakCaptionLabel?.textColor = .black
        streakCaptionLabel?.numberOfLines = 2
        streakCaptionLabel?.textAlignment = .center
        streakTitleLabel?.removeCharacterSpacing()
        streakCountLabel?.removeCharacterSpacing()
        streakCaptionLabel?.removeCharacterSpacing()

        savingGoalsTitleLabel?.font = sectionHeadingFont
        savingGoalsTitleLabel?.textColor = AppColors.textPrimary
        savingGoalsTitleLabel?.removeCharacterSpacing()
        GoalNameLabel.font = MintFont.space(size: 24, weight: .bold)
        GoalNameLabel.textColor = AppColors.textPrimary
        SavedSoFarLabel.font = MintFont.space(size: 38, weight: .heavy)
        SavedSoFarLabel.textColor = AppColors.textPrimary
        SavedSoFarLabel.adjustsFontSizeToFitWidth = true
        SavedSoFarLabel.minimumScaleFactor = 0.82
        completedLabel?.font = MintFont.space(size: 24, weight: .semibold)
        completedLabel?.textColor = AppColors.textPrimary
        GoalNameLabel.removeCharacterSpacing()
        SavedSoFarLabel.removeCharacterSpacing()
        completedLabel?.removeCharacterSpacing()

        upcomingBillsTitleLabel?.font = sectionHeadingFont
        upcomingBillsTitleLabel?.textColor = AppColors.textPrimary
        upcomingBillsTitleLabel?.removeCharacterSpacing()

        confirmTransactionsTitleLabel?.text = "CONFIRM TRANSACTIONS"
        confirmTransactionsTitleLabel?.font = sectionHeadingFont
        confirmTransactionsTitleLabel?.textColor = AppColors.textPrimary
        confirmTransactionsTitleLabel?.removeCharacterSpacing()

        recentTransactionsTitleLabel?.text = "RECENT TRANSACTIONS"
        recentTransactionsTitleLabel?.font = sectionHeadingFont
        recentTransactionsTitleLabel?.textColor = AppColors.textPrimary
        recentTransactionsTitleLabel?.removeCharacterSpacing()

        insightsLabel?.font = MintFont.space(size: 14, weight: .medium)
        insightsLabel?.textColor = AppColors.textPrimary
        insightsLabel?.numberOfLines = 0
        insightsLabel?.removeCharacterSpacing()

        for label in labels(in: view) {
            switch label.text {
            case "Confirm Transactions":
                label.text = "CONFIRM TRANSACTIONS"
                label.font = sectionHeadingFont
                label.textColor = AppColors.textPrimary
                label.removeCharacterSpacing()
            case "Recent Transactions":
                label.text = "RECENT TRANSACTIONS"
                label.font = sectionHeadingFont
                label.textColor = AppColors.textPrimary
                label.removeCharacterSpacing()
            case "DAILY AVERAGE", "STREAK", "SAVING GOALS", "UPCOMING BILLS", "CONFIRM TRANSACTIONS", "RECENT TRANSACTIONS":
                label.font = sectionHeadingFont
                label.textColor = label.text == "STREAK" ? .black : AppColors.textPrimary
                label.removeCharacterSpacing()
            case "/ per day":
                label.font = MintFont.space(size: 11, weight: .bold)
                label.textColor = AppColors.textSecondary
                label.removeCharacterSpacing()
            case "Completed":
                label.font = MintFont.space(size: 24, weight: .semibold)
                label.textColor = AppColors.textPrimary
                label.removeCharacterSpacing()
            default:
                break
            }
        }
    }

    func applyBaseTypography(in rootView: UIView?) {
        guard let rootView else { return }
        for label in labels(in: rootView) {
            guard label !== amountLabel,
                  label !== budgetAmountLabel,
                  label !== dailyAverage,
                  label !== streakCountLabel,
                  label !== SavedSoFarLabel,
                  label !== dashboardLabel,
                  label !== dailyAverageTitleLabel,
                  label !== dailyAverageUnitLabel,
                  label !== savingGoalsTitleLabel,
                  label !== completedLabel,
                  label !== streakTitleLabel,
                  label !== upcomingBillsTitleLabel,
                  label !== confirmTransactionsTitleLabel,
                  label !== recentTransactionsTitleLabel
            else { continue }

            label.font = MintFont.space(size: label.font.pointSize, weight: fontWeight(for: label.font))
            label.removeCharacterSpacing()
        }
    }

    func fontWeight(for font: UIFont) -> UIFont.Weight {
        let traits = font.fontDescriptor.symbolicTraits
        return traits.contains(.traitBold) ? .bold : .regular
    }

    func updateGoalImageMask() {
        guard let imageView = goalImageView else { return }
        imageView.layer.cornerRadius = min(imageView.bounds.width, imageView.bounds.height) / 2
        imageView.layer.masksToBounds = true
    }

    func labels(in rootView: UIView?) -> [UILabel] {
        guard let rootView else { return [] }
        return rootView.subviews.flatMap { subview -> [UILabel] in
            var result = labels(in: subview)
            if let label = subview as? UILabel {
                result.insert(label, at: 0)
            }
            return result
        }
    }

    func hideButtons(in rootView: UIView?) {
        guard let rootView else { return }
        for subview in rootView.subviews {
            if let button = subview as? UIButton {
                button.isHidden = true
            }
            hideButtons(in: subview)
        }
    }

    func installCornerRefreshIcon(on cardView: UIView?, tintColor: UIColor) {
        guard let cardView else { return }
        let tag = 711_004
        if cardView.viewWithTag(tag) != nil { return }

        let imageView = UIImageView(image: UIImage(systemName: "arrow.clockwise.circle"))
        imageView.tag = tag
        imageView.tintColor = tintColor.withAlphaComponent(0.9)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            imageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    func setHeightConstraint(on view: UIView?, to constant: CGFloat) {
        guard let view else { return }
        let constraints = view.constraints + (view.superview?.constraints ?? [])
        for constraint in constraints where constraint.firstAttribute == .height {
            if (constraint.firstItem as? UIView) === view || constraint.secondItem == nil {
                constraint.constant = constant
                return
            }
        }
    }

    func setTopConstraint(on view: UIView?, to constant: CGFloat) {
        guard let view else { return }
        let constraints = view.constraints + (view.superview?.constraints ?? [])
        for constraint in constraints where constraint.firstAttribute == .top {
            if (constraint.firstItem as? UIView) === view {
                constraint.constant = constant
                return
            }
        }
    }

    @objc func showProfile() {
        let profile = storyboard?.instantiateViewController(withIdentifier: "ProfileViewController")
        guard let profile else { return }
        navigationController?.pushViewController(profile, animated: true)
    }

    func compactCurrency(_ amount: Double) -> String {
        let rounded = Int(amount.rounded())
        return "₹\(rounded.formatted(.number.grouping(.automatic)))"
    }

    func compactShortCurrency(_ amount: Double) -> String {
        let rounded = Int(amount.rounded())
        if rounded >= 1000, rounded % 1000 == 0 {
            return "\(rounded / 1000)k"
        }
        return compactCurrency(amount)
    }
}

private extension UIView {
    func applyGradient(colors: [CGColor], name: String) {
        let gradient = (layer.sublayers?.first { $0.name == name } as? CAGradientLayer) ?? CAGradientLayer()
        gradient.name = name
        gradient.colors = colors
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = bounds

        if gradient.superlayer == nil {
            layer.insertSublayer(gradient, at: 0)
        }
    }
}
