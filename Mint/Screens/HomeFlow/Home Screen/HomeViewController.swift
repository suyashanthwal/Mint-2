
import UIKit
import SDWebImage

class HomeViewController: UIViewController, UICollectionViewDelegate {

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
    
    @IBOutlet weak var AverageUpAndDownLabel: UILabel!
    @IBOutlet weak var dailyAverage: UILabel!

    @IBOutlet weak var averageCardsView: UIView!
    @IBOutlet weak var goalsCardView: UIView!
    @IBOutlet weak var GoalNameLabel: UILabel!
    @IBOutlet weak var SavedSoFarLabel: UILabel!
    @IBOutlet weak var goalImageView: UIImageView?
    @IBOutlet weak var streakCountLabel: UILabel?
    @IBOutlet weak var streakCaptionLabel: UILabel?
    @IBOutlet weak var streakFireImageView: UIImageView?
    @IBOutlet weak var goalProgressContainerView: UIView?
    
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
    private var categories: [Category] = []
    private let contextMenuFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let actionFeedbackGenerator = UINotificationFeedbackGenerator()

    private var spotlightView: OnboardingSpotlightView?
    private var currentOnboardingStep = 0
    private var onboardingSteps: [OnboardingStep] = []

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasCheckedOnboarding else { return }
        hasCheckedOnboarding = true

        if OnboardingHelper.shouldShow(key: OnboardingKeys.home) {
            showHomeOnboarding()
            OnboardingHelper.markSeen(key: OnboardingKeys.home)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    private func loadDataFromDatabase() {
        let db = DatabaseManager.shared

        categories        = db.fetchCategories()
        allTransactions   = db.fetchTransactions()
        transactions      = db.fetchRecentTransactions(limit: 5)
        pendingTransactions = db.fetchBufferedTransactions()
        allBills          = db.fetchBills()
        recurringPayments = db.fetchRecurringPayments()
        upcomingItems     = buildUpcomingItemsForHome()
        goals             = db.fetchGoals()
        currentBudget     = db.fetchCurrentBudget()

        if isViewLoaded {
            updateHomeCollectionLayouts()
        }

        updateMonthlyOverview()
        updateDailyAverageCard()
        updateStreakCard()
        updateGoalCard()

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
            ? "you have \(compactCurrency(remainingAmount)) left"
            : "set a budget to track this month"
    }

    private func updateDailyAverageCard() {
        let calendar = Calendar.current
        let monthlyExpense = currentMonthExpenseTransactions().reduce(0) { $0 + $1.amount }
        let daysElapsed = max(calendar.component(.day, from: Date()), 1)
        let actualDailyAverage = monthlyExpense / Double(daysElapsed)
        let todaysSpending = todaysExpenseTransactions().reduce(0) { $0 + $1.amount }
        let dailyBudget = currentDailyBudget()

        dailyAverage.text = compactCurrency(actualDailyAverage)

        guard dailyBudget > 0 else {
            AverageUpAndDownLabel.attributedText = nil
            AverageUpAndDownLabel.text = "Set a budget to track today"
            return
        }

        if todaysSpending == 0 {
            AverageUpAndDownLabel.attributedText = nil
            AverageUpAndDownLabel.text = "You haven't spent anything"
            return
        }

        let streak = continuousUnderBudgetDays()
        if streak >= 10, let daysEarlier = estimatedGoalAccelerationDays(), daysEarlier > 0 {
            AverageUpAndDownLabel.attributedText = nil
            AverageUpAndDownLabel.text = "Goal \(daysEarlier)d earlier"
            return
        }

        AverageUpAndDownLabel.attributedText = nil
        if todaysSpending <= dailyBudget {
            AverageUpAndDownLabel.text = streak >= 3 ? "Keep the streak alive" : "You are on track today"
        } else if todaysSpending <= dailyBudget * 1.15 {
            AverageUpAndDownLabel.text = "Slightly over today"
        } else {
            AverageUpAndDownLabel.text = "Slow down for today"
        }
    }

    private func updateStreakCard() {
        let streak = continuousUnderBudgetDays()
        streakCountLabel?.text = "\(streak)x"
        streakCaptionLabel?.text = streak == 1 ? "day under budget" : "days under budget"
    }

    private func updateGoalCard() {
        let mostCompletedActiveGoal = goals
            .filter { !$0.isCompleted && $0.progress < 1 }
            .max { $0.progress < $1.progress }
        let latestCompletedGoal = goals
            .filter { $0.isCompleted || $0.progress >= 1 }
            .sorted { ($0.completedOn ?? .distantPast) > ($1.completedOn ?? .distantPast) }
            .first
        let displayedGoal = mostCompletedActiveGoal ?? latestCompletedGoal

        if let goal = displayedGoal {
            let progressPercent = Int(round(Double(goal.progress) * 100))
            selectedGoalProgress = CGFloat(goal.progress)
            GoalNameLabel.text = goal.name
            SavedSoFarLabel.attributedText = nil
            SavedSoFarLabel.text = "\(progressPercent)%"
            applyGoalImage(for: goal)
            renderGoalProgress()
            return
        }

        selectedGoalProgress = 0
        GoalNameLabel.text = "No goal yet"
        SavedSoFarLabel.attributedText = nil
        SavedSoFarLabel.text = "0%"
        goalImageView?.image = UIImage(systemName: "target")
        goalImageView?.contentMode = .scaleAspectFit
        goalImageView?.tintColor = AppColors.textPrimary
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
            .filter({ !$0.isCompleted && $0.progress < 1 })
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

    private func toggleBillPaymentState(for billId: UUID) {
        guard let bill = allBills.first(where: { $0.id == billId }) else { return }

        let db = DatabaseManager.shared
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
        let db = DatabaseManager.shared
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
        let db = DatabaseManager.shared
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
        confirmCardView.layer.masksToBounds = true

        confirmCollectionView.register(
            UINib(nibName: "ConfirmationTransactionsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "ConfirmTransactionCell"
        )
        confirmCollectionView.collectionViewLayout = generateConfirmLayout()
        confirmCollectionView.isScrollEnabled = false
        confirmCollectionView.backgroundColor = AppColors.card
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
        transactionsCollectionView.layer.cornerRadius = 22
        transactionsCollectionView.layer.masksToBounds = true
        transactionsCollectionView.backgroundColor = AppColors.card
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
            widthDimension: upcomingItems.isEmpty ? .fractionalWidth(1.0) : .absolute(140),
            heightDimension: upcomingItems.isEmpty ? .fractionalHeight(1.0) : .absolute(180)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = upcomingItems.isEmpty ? .none : .continuous
        section.interGroupSpacing = upcomingItems.isEmpty ? 0 : 16 // slightly more breathing room
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

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

        styleLabels(in: view, color: AppColors.textPrimary)
        styleLabels(in: goalcardview, color: .black)
        [budgetAmountLabel, monthlyRemainingLabel, AverageUpAndDownLabel].forEach {
            $0?.textColor = AppColors.textSecondary
        }
        styleCard(MonthlyView, cornerRadius: 18)
        styleCard(averageCardsView, cornerRadius: 18, borderColor: AppColors.cardBorder)
        styleCard(goalcardview, cornerRadius: 18, fillColor: AppColors.orange)
        styleCard(goalsCardView, cornerRadius: 18)

        MonthlyView.clipsToBounds = true
        goalsCardView.clipsToBounds = true
        averageCardsView.backgroundColor = AppColors.card
        goalcardview.backgroundColor = AppColors.orange

        goalImageView?.contentMode = .scaleAspectFit
        goalProgressContainerView?.backgroundColor = .clear
        goalProgressContainerView?.layer.cornerRadius = (goalProgressContainerView?.bounds.width ?? 100) / 2
        goalProgressContainerView?.clipsToBounds = false
        loadFireAnimation()
        profileButton?.tintColor = AppColors.textPrimary
        profileButton?.addTarget(self, action: #selector(showProfile), for: .touchUpInside)
    }

    func applyDashboardGradients() {
        MonthlyView.applyGradient(colors: AppColors.brandGradient, name: "monthlyGradient")
        goalsCardView.applyGradient(colors: AppColors.goalGradient, name: "goalGradient")
    }

    func loadFireAnimation() {
        guard let url = URL(string: "https://lottie.host/dea06fab-bb4c-4c95-ad29-66b83f17e78c/jmabSDGz4q.lottie") else {
            streakFireImageView?.image = UIImage(systemName: "flame.fill")
            return
        }

        streakFireImageView?.sd_setImage(
            with: url,
            placeholderImage: UIImage(systemName: "flame.fill")
        )
        streakFireImageView?.tintColor = AppColors.error
    }

    func renderGoalProgress() {
        guard let container = goalProgressContainerView, container.bounds.width > 0 else { return }
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
        track.strokeColor = UIColor.white.withAlphaComponent(0.72).cgColor
        track.lineWidth = lineWidth

        let ring = CAShapeLayer()
        ring.name = "goalProgressRing"
        ring.path = path.cgPath
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = AppColors.success.cgColor
        ring.lineWidth = lineWidth
        ring.lineCap = .butt
        ring.strokeEnd = min(max(selectedGoalProgress, 0), 1)

        container.layer.addSublayer(track)
        container.layer.addSublayer(ring)
    }

    func applyGoalImage(for goal: Goal) {
        if let image = savedGoalImage(for: goal) {
            goalImageView?.image = image
            goalImageView?.contentMode = .scaleAspectFill
            goalImageView?.tintColor = nil
        } else if let imageName = goal.imageName, let image = UIImage(named: imageName) {
            goalImageView?.image = image
            goalImageView?.contentMode = .scaleAspectFill
            goalImageView?.tintColor = nil
        } else {
            goalImageView?.image = UIImage(systemName: goal.iconName)
            goalImageView?.contentMode = .scaleAspectFit
            goalImageView?.tintColor = AppColors.textPrimary
        }
    }

    func savedGoalImage(for goal: Goal) -> UIImage? {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("goal_\(goal.id.uuidString)_photo.jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
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

    @objc func showProfile() {
        let profile = storyboard?.instantiateViewController(withIdentifier: "ProfileViewController")
        guard let profile else { return }
        navigationController?.pushViewController(profile, animated: true)
    }

    func compactCurrency(_ amount: Double) -> String {
        let rounded = Int(amount.rounded())
        return "₹\(rounded.formatted(.number.grouping(.automatic)))"
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
