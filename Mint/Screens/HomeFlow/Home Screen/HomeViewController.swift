//
//  HomeViewController.swift
//  JustChecking
//
//  Created by Suyash Anthwal on 22/03/26.
//

import UIKit

class HomeViewController: UIViewController, UICollectionViewDelegate {

    // MARK: - Outlets

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var todaycardview: UIView!
    @IBOutlet weak var goalcardview: UIView!
    @IBOutlet weak var recentcardview: UIView!
    @IBOutlet weak var upcomingcardview: UIView!

    @IBOutlet weak var MonthlyView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!

    @IBOutlet private weak var confirmCardView: UIView!
    @IBOutlet private weak var confirmSectionContainerView: UIView!
    @IBOutlet private weak var transactionsCollectionView: UICollectionView!
    @IBOutlet private weak var billsCollectionView: UICollectionView!
    @IBOutlet weak var confirmCollectionView: UICollectionView!
    
    @IBOutlet weak var dailyAverageTarget: UILabel!
    @IBOutlet weak var dailyAverage: UILabel!
    // MARK: - Properties

    @IBOutlet weak var percentCompleted: UILabel!
    @IBOutlet weak var goalName: UILabel!
    @IBOutlet weak var averageIndicator: UIImageView!
    
    private var hasCheckedOnboarding = false
    let circularProgress = CircularProgressView()
    private var transactions: [Transaction] = []
    private var allTransactions: [Transaction] = []
    private var pendingTransactions: [BufferedTransaction] = []
    private var bills: [Bill] = []
    private var allBills: [Bill] = []
    private var goals: [Goal] = []
    private var recurringPayments: [RecurringPayment] = []
    private var currentBudget: Budget?
    private var monthlyProgressValue: CGFloat = 0
    private var categories: [Category] = []
    private let contextMenuFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let actionFeedbackGenerator = UINotificationFeedbackGenerator()


    // MARK: - Onboarding State

    private var spotlightView: OnboardingSpotlightView?
    private var currentOnboardingStep = 0
    private var onboardingSteps: [OnboardingStep] = []

    // MARK: - Lifecycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        loadDataFromDatabase()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        showHomeOnboarding()
        todaycardview.applyShadow()
        goalcardview.applyShadow()
        MonthlyView.backgroundColor = .clear

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
                view: goalcardview,
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
    
    // MARK: - Data Loading
    
    private func loadDataFromDatabase() {
        let db = DatabaseManager.shared

        // Categories must be loaded first — transactions cell uses them for icon lookup
        categories        = db.fetchCategories()
        allTransactions   = db.fetchTransactions()
        transactions      = db.fetchRecentTransactions(limit: 5)
        pendingTransactions = db.fetchBufferedTransactions()
        allBills          = db.fetchBills()
        bills             = upcomingBillsForHome()
        recurringPayments = db.fetchRecurringPayments()
        goals             = db.fetchGoals()
        currentBudget     = db.fetchCurrentBudget()

        updateMonthlyOverview()
        updateDailyAverageCard()
        updateGoalCard()

        updateConfirmSectionVisibility()
        confirmCollectionView.reloadData()
        transactionsCollectionView.reloadData()
        billsCollectionView.reloadData()
    }

    private func upcomingBillsForHome() -> [Bill] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return allBills
            .filter { $0.billDate >= startOfToday }
            .sorted { lhs, rhs in
                if lhs.isPaid != rhs.isPaid {
                    return !lhs.isPaid && rhs.isPaid
                }
                return lhs.billDate < rhs.billDate
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
    
    // MARK: - Onboarding

    private func showHomeOnboarding() {
        startOnboarding()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        confirmCollectionView.collectionViewLayout.invalidateLayout()
        transactionsCollectionView.collectionViewLayout.invalidateLayout()
        renderMonthlyProgress()
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

    // MARK: - Home Cards

    private func updateMonthlyOverview() {
        let monthlyExpense = currentMonthExpenseTransactions().reduce(0) { $0 + $1.amount }
        amountLabel.text = currencyFormatter.string(from: NSNumber(value: monthlyExpense)) ?? "₹0"

        let budgetAmount = currentBudget?.allocatedBudget ?? 0
        monthlyProgressValue = budgetAmount > 0
            ? CGFloat(min(monthlyExpense / budgetAmount, 1))
            : 0

        renderMonthlyProgress()
    }

    private func renderMonthlyProgress() {
        guard MonthlyView.bounds.width > 0, MonthlyView.bounds.height > 0 else { return }

        circularProgress.setupCircularProgress(
            on: MonthlyView,
            progress: monthlyProgressValue,
            lineWidth: 10.0
        )
    }

    private func updateDailyAverageCard() {
        let calendar = Calendar.current
        let monthlyExpense = currentMonthExpenseTransactions().reduce(0) { $0 + $1.amount }
        let daysElapsed = max(calendar.component(.day, from: Date()), 1)
        let actualDailyAverage = monthlyExpense / Double(daysElapsed)

        dailyAverage.text = currencyFormatter.string(from: NSNumber(value: actualDailyAverage)) ?? "₹0"

        let fixedExpenses = currentMonthFixedExpenses()
        let totalBudget = currentBudget?.allocatedBudget ?? 0
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        let targetDailyAverage = max(totalBudget - fixedExpenses, 0) / Double(daysInMonth)

        dailyAverageTarget.text = "Target \(currencyFormatter.string(from: NSNumber(value: targetDailyAverage)) ?? "₹0")"
        updateAverageIndicator(actual: actualDailyAverage, target: targetDailyAverage)
    }

    private func updateAverageIndicator(actual: Double, target: Double) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let symbolName: String
        let tintColor: UIColor

        if actual == 0 && target == 0 {
            symbolName = "minus.circle.fill"
            tintColor = AppColors.textSecondary
        } else if actual <= target {
            symbolName = "arrow.down.circle.fill"
            tintColor = AppColors.brand
        } else {
            symbolName = "arrow.up.circle.fill"
            tintColor = AppColors.error
        }

        averageIndicator.image = UIImage(systemName: symbolName, withConfiguration: configuration)
        averageIndicator.tintColor = tintColor
    }

    private func updateGoalCard() {
        let mostCompletedActiveGoal = goals
            .filter { !$0.isCompleted && $0.progress < 1 }
            .max { $0.progress < $1.progress }

        if let goal = mostCompletedActiveGoal {
            let progressPercent = Int(goal.progress * 100)
            percentCompleted.text = "\(progressPercent)%"
            goalName.text = goal.name
            return
        }

        if goals.contains(where: { $0.isCompleted || $0.progress >= 1 }) {
            percentCompleted.text = "100%"
            goalName.text = "All goals completed"
        } else {
            percentCompleted.text = "—"
            goalName.text = "No goals yet"
        }
    }

    private func currentMonthExpenseTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return allTransactions.filter {
            $0.type == .expense &&
            calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month)
        }
    }

    private func currentMonthFixedExpenses() -> Double {
        let calendar = Calendar.current
        let now = Date()

        let recurringTotal = recurringPayments
            .filter { $0.isActive && !$0.isIncome }
            .reduce(0) { $0 + $1.amount }

        let currentMonthBillsTotal = allBills
            .filter {
                calendar.isDate($0.billDate, equalTo: now, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.amount }

        return recurringTotal + currentMonthBillsTotal
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

    // MARK: - Collection View Setup

    private func setupConfirmCollectionView() {
        confirmCardView.backgroundColor = AppColors.card
        confirmCardView.layer.cornerRadius = 22
        confirmCardView.layer.masksToBounds = true

        confirmCollectionView.register(
            UINib(nibName: "ConfirmationTransactionsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "ConfirmTransactionCell"
        )
        confirmCollectionView.collectionViewLayout = generateConfirmLayout()
        confirmCollectionView.isScrollEnabled = false
        confirmCollectionView.backgroundColor = .systemGray4
        confirmCollectionView.showsVerticalScrollIndicator = false
        confirmCollectionView.dataSource = self
        confirmCollectionView.delegate = self
    }
    private func setupTransactionsCollectionView() {
        transactionsCollectionView.register(
            UINib(nibName: "RecentTransactionsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "RecentTransactionCell"
        )
        transactionsCollectionView.collectionViewLayout = generateVerticalLayout()
        transactionsCollectionView.isScrollEnabled = false
        transactionsCollectionView.backgroundColor = .systemGray4
        transactionsCollectionView.dataSource = self
        transactionsCollectionView.delegate   = self
    }

    private func setupBillsCollectionView() {
        billsCollectionView.register(
            UINib(nibName: "UpcomingBillsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "UpcomingBillsCell"
        )
        billsCollectionView.collectionViewLayout = generateHorizontalLayout()
        billsCollectionView.showsHorizontalScrollIndicator = false
        billsCollectionView.dataSource = self
        billsCollectionView.delegate   = self
    }

    // MARK: - Layouts

    private func generateVerticalLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(52)
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
            heightDimension: .absolute(52)
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
            widthDimension: .absolute(120),
            heightDimension: .absolute(92)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 12

        return UICollectionViewCompositionalLayout(section: section)
    }

}

// MARK: - UICollectionViewDataSource

extension HomeViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView == confirmCollectionView {
            return pendingTransactions.count
        } else if collectionView == billsCollectionView {
            return bills.count
        } else {
            return min(transactions.count, 5)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

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
            cell.configureCell(with: bills[indexPath.row])
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
            let transaction = transactions[indexPath.item]
            contextMenuFeedbackGenerator.prepare()
            contextMenuFeedbackGenerator.impactOccurred()

            return UIContextMenuConfiguration(identifier: transaction.id.uuidString as NSString, previewProvider: nil) { [weak self] _ in
                let deleteAction = UIAction(
                    title: "Delete",
                    image: UIImage(systemName: "trash"),
                    attributes: .destructive
                ) { _ in
                    self?.promptDeleteTransaction(transaction)
                }

                return UIMenu(title: transaction.name, children: [deleteAction])
            }
        }

        if collectionView == billsCollectionView {
            let bill = bills[indexPath.item]
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
