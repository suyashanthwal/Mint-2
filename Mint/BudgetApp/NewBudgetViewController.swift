import UIKit

private enum NewBudgetSubsOrBillItem {
    case subscription(RecurringPayment)
    case bill(Bill)
}

final class NewBudgetViewController: UIViewController {

    @IBOutlet private weak var headerView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var profileButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentStackView: UIStackView!

    @IBOutlet private weak var budgetOverviewContainerView: UIView?
    @IBOutlet private weak var budgetSectionHeightConstraint: NSLayoutConstraint?
    @IBOutlet private weak var totalSpendingCardView: UIView!
    @IBOutlet private weak var totalBudgetTitleLabel: UILabel!
    @IBOutlet private weak var totalBudgetAmountLabel: UILabel!
    @IBOutlet private weak var daysLeftLabel: UILabel!
    @IBOutlet private weak var spentLabel: UILabel!
    @IBOutlet private weak var editButton: UIButton!
    @IBOutlet private weak var breakdownToggleButton: UIButton?
    @IBOutlet private weak var breakdownContainerView: UIView?
    @IBOutlet private weak var breakdownTitleLabel: UILabel?
    @IBOutlet private weak var breakdownHeightConstraint: NSLayoutConstraint?
    @IBOutlet private weak var breakdownTopSpacingConstraint: NSLayoutConstraint?
    @IBOutlet private weak var breakdownCardsTopConstraint: NSLayoutConstraint?

    @IBOutlet private var metricCardViews: [UIView]!
    @IBOutlet private var metricTitleLabels: [UILabel]!
    @IBOutlet private var metricAmountLabels: [UILabel]!

    @IBOutlet private weak var categoriesTitleLabel: UILabel!
    @IBOutlet private weak var addCategoryButton: UIButton?
    @IBOutlet private weak var categoriesCollectionView: UICollectionView!
    @IBOutlet private weak var categoriesPageControl: UIPageControl!
    @IBOutlet private weak var subsAndBillsTitleLabel: UILabel!
    @IBOutlet private weak var addSubsAndBillsButton: UIButton?
    @IBOutlet private weak var subsAndBillsCollectionView: UICollectionView!
    @IBOutlet private weak var savingGoalsTitleLabel: UILabel!
    @IBOutlet private weak var addGoalButton: UIButton?
    @IBOutlet private weak var goalsCollectionView: UICollectionView!

    private var categories: [Category] = []
    private var goals: [Goal] = []
    private var recurringPayments: [RecurringPayment] = []
    private var bills: [Bill] = []
    private var transactions: [Transaction] = []
    private var currentBudget: Budget?
    private var subsAndBillsItems: [NewBudgetSubsOrBillItem] = []
    private var isBreakdownExpanded = false
    private var hasCheckedOnboarding = false
    private var spotlightView: OnboardingSpotlightView?
    private var currentOnboardingStep = 0
    private var onboardingSteps: [OnboardingStep] = []
    private let categoriesPerPage = 4
    private let categoryGridRows = 2
    private let categoryGridColumns = 2
    private let categoryGridSpacing: CGFloat = 20
    private let categoryGridCellHeight: CGFloat = 140
    private let totalBudgetCardHeight: CGFloat = 160
    private let expandedBreakdownHeight: CGFloat = 282
    private var totalBudgetCardHeightConstraint: NSLayoutConstraint?
    private var expandedBudgetHeight: CGFloat {
        totalBudgetCardHeight + expandedBreakdownHeight
    }
    private var collapsedBudgetHeight: CGFloat {
        totalBudgetCardHeight
    }

    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        reloadAll()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasCheckedOnboarding else { return }
        hasCheckedOnboarding = true

        if OnboardingHelper.shouldShow(key: OnboardingKeys.budget) {
            configureOnboardingSteps()
            startOnboarding()
            OnboardingHelper.markSeen(key: OnboardingKeys.budget)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollections()
        setupUI()
        applyBreakdownState(animated: false)
        observeDataChanges()
        reloadAll()
        contentStackView.isLayoutMarginsRelativeArrangement = true
        contentStackView.layoutMargins = UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyBudgetGradient()
        categoriesCollectionView.collectionViewLayout.invalidateLayout()
        subsAndBillsCollectionView.collectionViewLayout.invalidateLayout()
        goalsCollectionView.collectionViewLayout.invalidateLayout()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureOnboardingSteps() {
        onboardingSteps = [
            OnboardingStep(
                view: totalSpendingCardView,
                title: "Total Budget",
                message: "See this month’s budget, current spending, and time left in one place.",
                tooltipBelow: true
            ),
            OnboardingStep(
                view: categoriesCollectionView,
                title: "Categories",
                message: "Long press a category to set limits, edit details, or delete it.",
                tooltipBelow: false
            ),
            OnboardingStep(
                view: subsAndBillsCollectionView,
                title: "Subs & Bills",
                message: "Track recurring payments and mark bills paid directly from the hold menu.",
                tooltipBelow: false
            ),
            OnboardingStep(
                view: goalsCollectionView,
                title: "Saving Goals",
                message: "Review monthly saving commitments and edit goals when plans change.",
                tooltipBelow: false
            )
        ]
    }

    private func startOnboarding() {
        guard !onboardingSteps.isEmpty else { return }

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
        } completion: { [weak self] _ in
            self?.showCurrentOnboardingStep(animated: false)
        }
    }

    private func advanceOnboarding() {
        currentOnboardingStep += 1

        if currentOnboardingStep < onboardingSteps.count {
            showCurrentOnboardingStep(animated: true)
        } else {
            finishOnboarding()
        }
    }

    private func showCurrentOnboardingStep(animated: Bool) {
        guard onboardingSteps.indices.contains(currentOnboardingStep) else { return }
        let step = onboardingSteps[currentOnboardingStep]

        spotlightView?.isUserInteractionEnabled = false
        scrollToOnboardingStep(step, animated: animated) { [weak self] in
            guard let self else { return }
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

    private func scrollToOnboardingStep(
        _ step: OnboardingStep,
        animated: Bool,
        completion: @escaping () -> Void
    ) {
        let targetRect = step.view.convert(step.view.bounds.insetBy(dx: -16, dy: -16), to: scrollView)
        let visibleHeight = max(scrollView.bounds.height - scrollView.adjustedContentInset.top - scrollView.adjustedContentInset.bottom, 1)
        let targetY = min(
            max(targetRect.midY - (visibleHeight * 0.42), -scrollView.adjustedContentInset.top),
            max(scrollView.contentSize.height - visibleHeight + scrollView.adjustedContentInset.bottom, -scrollView.adjustedContentInset.top)
        )

        UIView.animate(
            withDuration: animated ? 0.42 : 0,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: {
                self.scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: false)
            },
            completion: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: completion)
            }
        )
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

    private func setupCollections() {
        categoriesCollectionView.register(
            UINib(nibName: CategoryCollectionViewCell.reuseIdentifier, bundle: nil),
            forCellWithReuseIdentifier: CategoryCollectionViewCell.reuseIdentifier
        )
        subsAndBillsCollectionView.register(
            UINib(nibName: BillCollectionViewCell.reuseIdentifier, bundle: nil),
            forCellWithReuseIdentifier: BillCollectionViewCell.reuseIdentifier
        )
        goalsCollectionView.register(
            UINib(nibName: GoalCollectionViewCell.reuseIdentifier, bundle: nil),
            forCellWithReuseIdentifier: GoalCollectionViewCell.reuseIdentifier
        )
        [categoriesCollectionView, subsAndBillsCollectionView, goalsCollectionView].forEach {
            $0?.dataSource = self
            $0?.delegate = self
            $0?.backgroundColor = .clear
            $0?.showsHorizontalScrollIndicator = false
            $0?.showsVerticalScrollIndicator = false
            if let collectionView = $0 {
                allowContextMenuPreviewOverflow(for: collectionView)
            }
        }
        categoriesCollectionView.clipsToBounds = true
        categoriesCollectionView.layer.masksToBounds = true
        categoriesCollectionView.isScrollEnabled = true
        categoriesCollectionView.collectionViewLayout = makeCategoriesGridLayout()
        categoriesPageControl.addTarget(self, action: #selector(categoriesPageChanged(_:)), for: .valueChanged)
    }

    private func setupUI() {
        view.backgroundColor = AppColors.background
        headerView.backgroundColor = AppColors.background
        scrollView.backgroundColor = AppColors.background
        scrollView.indicatorStyle = .white
        contentStackView.backgroundColor = AppColors.background

        titleLabel.textColor = AppColors.textPrimary
        titleLabel.font = MintFont.space(size: 25, weight: .bold)
        titleLabel.removeCharacterSpacing()

        profileButton.tintColor = AppColors.background
        profileButton.backgroundColor = AppColors.textPrimary
        profileButton.layer.cornerRadius = 17
        profileButton.addTarget(self, action: #selector(showProfile), for: .touchUpInside)

        enforceTotalBudgetCardHeight()
        applyBudgetGradient()
        budgetOverviewContainerView?.backgroundColor = AppColors.background
        budgetOverviewContainerView?.layer.cornerRadius = 18
        budgetOverviewContainerView?.layer.borderColor = AppColors.budgetBreakdownBorder.cgColor
        budgetOverviewContainerView?.layer.borderWidth = 1.5
        budgetOverviewContainerView?.clipsToBounds = true

        totalSpendingCardView.layer.cornerRadius = 18
        totalSpendingCardView.clipsToBounds = true
        totalBudgetTitleLabel.textColor = AppColors.brandText
        totalBudgetAmountLabel.textColor = AppColors.brandText
        daysLeftLabel.textColor = AppColors.brandLightText
        spentLabel.textColor = AppColors.brandLightText

        var config = UIButton.Configuration.plain()
        config.title = "Edit"
        config.baseForegroundColor = AppColors.brandText
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
        editButton.configuration = config
        editButton.layer.borderColor = AppColors.brandLightText.withAlphaComponent(0.55).cgColor
        editButton.layer.borderWidth = 1
        editButton.layer.cornerRadius = 15
        editButton.addTarget(self, action: #selector(editBudgetTapped), for: .touchUpInside)

        breakdownContainerView?.backgroundColor = AppColors.budgetBreakdownBackground
        breakdownTitleLabel?.textColor = AppColors.textPrimary
        breakdownTitleLabel?.font = MintFont.space(size: 16, weight: .bold)
        breakdownTitleLabel?.removeCharacterSpacing()
        breakdownTopSpacingConstraint?.constant = 0
        breakdownCardsTopConstraint?.constant = 74
        var toggleConfig = UIButton.Configuration.plain()
        toggleConfig.baseForegroundColor = AppColors.brandText
        toggleConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        breakdownToggleButton?.configuration = toggleConfig
        breakdownToggleButton?.tintColor = AppColors.brandText
        breakdownToggleButton?.addTarget(self, action: #selector(toggleBreakdownTapped), for: .touchUpInside)

        metricCardViews.forEach {
            $0.backgroundColor = AppColors.budgetBreakdownCard
            $0.layer.cornerRadius = 16
            $0.layer.borderColor = AppColors.budgetBreakdownBorder.cgColor
            $0.layer.borderWidth = 1.25
        }
        applyMetricTypography()

        [categoriesTitleLabel, subsAndBillsTitleLabel, savingGoalsTitleLabel].forEach {
            $0?.textColor = AppColors.textPrimary
            $0?.font = MintFont.space(size: 16, weight: .bold)
            $0?.removeCharacterSpacing()
        }

        applyBudgetTypography()

        configureAddButton(addCategoryButton, action: #selector(addCategoryTapped), accessibilityLabel: "Add category")
        configureAddButton(addSubsAndBillsButton, action: #selector(addSubsAndBillsTapped), accessibilityLabel: "Add subscription or bill")
        configureAddButton(addGoalButton, action: #selector(addGoalTapped), accessibilityLabel: "Add goal")

        categoriesPageControl.currentPageIndicatorTintColor = AppColors.brand
        categoriesPageControl.pageIndicatorTintColor = AppColors.brand.withAlphaComponent(0.3)
    }

    private func enforceTotalBudgetCardHeight() {
        if totalBudgetCardHeightConstraint == nil {
            let constraint = totalSpendingCardView.heightAnchor.constraint(equalToConstant: totalBudgetCardHeight)
            constraint.priority = .required
            constraint.isActive = true
            totalBudgetCardHeightConstraint = constraint
        }
        totalBudgetCardHeightConstraint?.constant = totalBudgetCardHeight
    }

    private func applyBudgetGradient() {
        totalSpendingCardView.applyGradient(
            colors: [
                UIColor(hex: "#641AEF").cgColor,
                UIColor(hex: "#9428FF").cgColor
            ],
            name: "monthlyGradient"
        )
    }

    private func applyBudgetTypography() {
        totalBudgetTitleLabel.textColor = AppColors.brandText
        totalBudgetTitleLabel.font = MintFont.space(size: 16, weight: .bold)
        totalBudgetTitleLabel.removeCharacterSpacing()

        totalBudgetAmountLabel.textColor = AppColors.brandText
        totalBudgetAmountLabel.font = MintFont.space(size: 36, weight: .heavy)
        totalBudgetAmountLabel.removeCharacterSpacing()

        daysLeftLabel.textColor = AppColors.brandLightText
        daysLeftLabel.font = MintFont.space(size: 14, weight: .semibold)
        daysLeftLabel.removeCharacterSpacing()

        spentLabel.textColor = AppColors.brandLightText
        spentLabel.font = MintFont.space(size: 14, weight: .semibold)
        spentLabel.removeCharacterSpacing()

        editButton.titleLabel?.font = MintFont.space(size: 14, weight: .semibold)
        if var config = editButton.configuration {
            var title = AttributedString("Edit")
            title.font = MintFont.space(size: 14, weight: .semibold)
            config.attributedTitle = title
            config.baseForegroundColor = AppColors.brandText
            editButton.configuration = config
        }
    }

    private func applyMetricTypography() {
        metricTitleLabels.forEach {
            $0.textColor = AppColors.textPrimary
            $0.font = MintFont.space(size: 14, weight: .semibold)
            $0.removeCharacterSpacing()
        }
        metricAmountLabels.forEach {
            $0.textColor = AppColors.textPrimary
            $0.font = MintFont.space(size: 14, weight: .bold)
            $0.removeCharacterSpacing()
        }
    }

    private func configureAddButton(_ button: UIButton?, action: Selector, accessibilityLabel: String) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "plus")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 12, weight: .regular))
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        button?.configuration = config
        button?.tintColor = .white
        button?.accessibilityLabel = accessibilityLabel
        button?.addTarget(self, action: action, for: .touchUpInside)
    }

    @objc private func toggleBreakdownTapped() {
        isBreakdownExpanded.toggle()
        applyBreakdownState(animated: true)
    }

    private func applyBreakdownState(animated: Bool) {
        let updates = {
            self.budgetSectionHeightConstraint?.constant = self.isBreakdownExpanded
                ? self.expandedBudgetHeight
                : self.collapsedBudgetHeight
            self.breakdownHeightConstraint?.constant = self.isBreakdownExpanded
                ? self.expandedBreakdownHeight
                : 0
            self.breakdownCardsTopConstraint?.constant = self.isBreakdownExpanded ? 74 : 0
            self.breakdownContainerView?.alpha = self.isBreakdownExpanded ? 1 : 0
            self.breakdownTitleLabel?.alpha = self.isBreakdownExpanded ? 1 : 0
            self.totalSpendingCardView.layer.maskedCorners = self.isBreakdownExpanded
                ? [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.breakdownContainerView?.layer.cornerRadius = 18
            self.breakdownContainerView?.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.view.layoutIfNeeded()
        }

        if isBreakdownExpanded { breakdownContainerView?.isHidden = false }
        updateBreakdownChevron()
        guard animated else {
            updates()
            breakdownContainerView?.isHidden = !isBreakdownExpanded
            return
        }

        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: updates,
            completion: { _ in
                self.breakdownContainerView?.isHidden = !self.isBreakdownExpanded
            }
        )
    }
    
    private func updateBreakdownChevron() {
        let imageName = isBreakdownExpanded ? "chevron.up" : "chevron.down"
        let image = UIImage(systemName: imageName)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))
        breakdownToggleButton?.setImage(image, for: .normal)
        breakdownToggleButton?.accessibilityLabel = isBreakdownExpanded ? "Collapse breakdown" : "Expand breakdown"
    }

    private func observeDataChanges() {
        let notifications: [Notification.Name] = [
            .categoryDataDidChange,
            .transactionDataDidChange,
            .goalDataDidChange,
            .budgetDataDidChange
        ]
        notifications.forEach {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleDataChange),
                name: $0,
                object: nil
            )
        }
    }

    private func reloadAll() {
        let db = DatabaseManager.shared
        categories = db.fetchCategories().filter { $0.type == .expense }
        goals = db.fetchGoals()
        recurringPayments = db.fetchRecurringPayments()
        bills = db.fetchBills()
        transactions = db.fetchTransactions()
        currentBudget = db.fetchCurrentBudget()
        buildSubsAndBillsList()
        updateSummary()
        updateCategoriesPageControl()
        categoriesCollectionView?.reloadData()
        subsAndBillsCollectionView?.reloadData()
        goalsCollectionView?.reloadData()
    }

    private func updateCategoriesPageControl() {
        let pages = categories.isEmpty ? 0 : Int(ceil(Double(categories.count) / Double(categoriesPerPage)))
        categoriesPageControl.numberOfPages = pages
        categoriesPageControl.currentPage = min(categoriesPageControl.currentPage, max(pages - 1, 0))
        categoriesPageControl.isHidden = pages <= 1
        categoriesPageControl.isUserInteractionEnabled = pages > 1
    }

    @objc private func categoriesPageChanged(_ sender: UIPageControl) {
        guard !categories.isEmpty else { return }
        let targetItem = min(sender.currentPage * categoriesPerPage, categories.count - 1)
        categoriesCollectionView.scrollToItem(
            at: IndexPath(item: targetItem, section: 0),
            at: .left,
            animated: true
        )
    }

    private func makeCategoriesGridLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(categoryGridColumns)),
            heightDimension: .absolute(categoryGridCellHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let rowSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(categoryGridCellHeight)
        )
        let rowGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: rowSize,
            repeatingSubitem: item,
            count: categoryGridColumns
        )
        rowGroup.interItemSpacing = .fixed(categoryGridSpacing)

        let groupHeight = (categoryGridCellHeight * CGFloat(categoryGridRows)) +
            (categoryGridSpacing * CGFloat(categoryGridRows - 1))
        let pageSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(groupHeight)
        )
        let pageGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: pageSize,
            repeatingSubitem: rowGroup,
            count: categoryGridRows
        )
        pageGroup.interItemSpacing = .fixed(categoryGridSpacing)

        let section = NSCollectionLayoutSection(group: pageGroup)
        section.orthogonalScrollingBehavior = .groupPaging
        section.visibleItemsInvalidationHandler = { [weak self] _, contentOffset, environment in
            guard let self else { return }
            let pageWidth = max(environment.container.effectiveContentSize.width, 1)
            let page = Int(round(contentOffset.x / pageWidth))
            self.categoriesPageControl.currentPage = min(max(page, 0), max(self.categoriesPageControl.numberOfPages - 1, 0))
        }

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func buildSubsAndBillsList() {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? startOfToday
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        var items = recurringPayments
            .filter { $0.isActive && !$0.isIncome }
            .map(NewBudgetSubsOrBillItem.subscription)

        let monthBills = bills.compactMap { bill -> NewBudgetSubsOrBillItem? in
            let billMonth = calendar.component(.month, from: bill.billDate)
            let billYear = calendar.component(.year, from: bill.billDate)
            let billDay = calendar.startOfDay(for: bill.billDate)
            let isCurrentMonth = billMonth == currentMonth && billYear == currentYear
            let isOverdueUnpaid = !bill.isPaid && billDay < currentMonthStart
            return isCurrentMonth || isOverdueUnpaid ? .bill(bill) : nil
        }
        items.append(contentsOf: monthBills)
        subsAndBillsItems = items.sorted { dueDate(for: $0) < dueDate(for: $1) }
    }

    private func updateSummary() {
        let allocated = currentBudget?.allocatedBudget ?? 0
        let spent = currentMonthExpenses().reduce(0) { $0 + $1.amount }
        let categoryBudget = categories.reduce(0) { $0 + $1.budget }
        let recurringTotal = recurringMonthlyTotal()
        let goalsMonthlyTotal = goals
            .filter(\.isActiveGoal)
            .reduce(0) { $0 + $1.monthlyGoal }
        let remaining = max(allocated - spent, 0)

        totalBudgetAmountLabel.text = compactCurrency(allocated)
        spentLabel.text = "\(compactCurrency(spent)) spent"
        daysLeftLabel.text = "\(daysLeftInMonth()) days left"

        setMetric(title: "Fixed", amount: compactCurrency(categoryBudget), at: 0)
        setMetric(title: "To spend", amount: compactCurrency(remaining), at: 1)
        setMetric(title: "Recurring", amount: compactCurrency(recurringTotal), at: 2)
        setMetric(title: "Saving Target", amount: compactCurrency(goalsMonthlyTotal), at: 3)
        applyMetricTypography()
        applyBudgetTypography()
    }

    private func setMetric(title: String, amount: String, at index: Int) {
        let titleLabels = sortedMetricLabels(metricTitleLabels)
        let amountLabels = sortedMetricLabels(metricAmountLabels)
        guard titleLabels.indices.contains(index),
              amountLabels.indices.contains(index) else { return }
        titleLabels[index].text = title
        amountLabels[index].text = amount
    }

    private func sortedMetricLabels(_ labels: [UILabel]) -> [UILabel] {
        labels.sorted { lhs, rhs in
            let lhsOrigin = lhs.superview?.convert(lhs.frame.origin, to: view) ?? lhs.frame.origin
            let rhsOrigin = rhs.superview?.convert(rhs.frame.origin, to: view) ?? rhs.frame.origin
            if abs(lhsOrigin.y - rhsOrigin.y) > 4 {
                return lhsOrigin.y < rhsOrigin.y
            }
            return lhsOrigin.x < rhsOrigin.x
        }
    }

    private func currentMonthExpenses() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        return transactions.filter {
            $0.type == .expense &&
            calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month)
        }
    }

    private func currentMonthExpense(for category: Category) -> Double {
        currentMonthExpenses()
            .filter { $0.categoryId == category.id }
            .reduce(0) { $0 + $1.amount }
    }

    private func recurringMonthlyTotal() -> Double {
        recurringPayments
            .filter { $0.isActive && !$0.isIncome }
            .reduce(0) { $0 + monthlyAmount(for: $1) }
    }

    private func monthlyAmount(for payment: RecurringPayment) -> Double {
        switch payment.duration {
        case .daily: return payment.amount * 30
        case .weekly: return payment.amount * 4
        case .monthly: return payment.amount
        case .quarterly: return payment.amount / 3
        case .halfYearly: return payment.amount / 6
        case .yearly: return payment.amount / 12
        }
    }

    private func daysLeftInMonth() -> Int {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: Date())
        let days = calendar.range(of: .day, in: .month, for: Date())?.count ?? day
        return max(days - day + 1, 0)
    }

    private func dueDate(for item: NewBudgetSubsOrBillItem) -> Date {
        switch item {
        case .subscription(let payment): return payment.nextDate
        case .bill(let bill): return bill.billDate
        }
    }

    private func categoryItem(for category: Category) -> BudgetCategoryItem {
        let spent = currentMonthExpense(for: category)
        let progress = category.budget > 0 ? min(Float(spent / category.budget), 1) : 0
        let accent = UIColor(hex: category.color)
        return BudgetCategoryItem(
            title: category.name,
            amount: "\(compactCurrency(spent)) / \(compactCurrency(category.budget))",
            symbolName: category.icon,
            progress: progress,
            accentColor: accent,
            backgroundColor: accent.withAlphaComponent(0.18),
            iconColor: accent.withAlphaComponent(0.34)
        )
    }

    private func billItem(for item: NewBudgetSubsOrBillItem) -> BudgetBillItem {
        switch item {
        case .subscription(let payment):
            return BudgetBillItem(
                title: payment.name,
                amount: compactCurrency(payment.amount),
                date: shortDate(payment.nextDate),
                symbolName: payment.icon ?? "creditcard.fill",
                dotColor: AppColors.brand
            )
        case .bill(let bill):
            return BudgetBillItem(
                title: bill.name,
                amount: compactCurrency(bill.amount),
                date: shortDate(bill.billDate),
                symbolName: bill.icon,
                dotColor: bill.isPaid ? AppColors.success : AppColors.error
            )
        }
    }

    private func goalItem(for goal: Goal) -> BudgetGoalItem {
        BudgetGoalItem(
            title: goal.name,
            amount: "\(compactCurrency(goal.monthlyGoal))/month",
            symbolName: goal.iconName
        )
    }

    @objc private func editBudgetTapped() {
        let currentAmount = currentBudget?.allocatedBudget ?? 0
        let alert = UIAlertController(
            title: "Edit Monthly Budget",
            message: "Category limits cannot exceed your total monthly budget.",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.keyboardType = .decimalPad
            textField.placeholder = "Monthly budget"
            textField.text = currentAmount > 0 ? String(Int(currentAmount)) : nil
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            guard let amount = self.parsedAmount(from: alert?.textFields?.first?.text), amount > 0 else {
                self.showAlert(title: "Invalid Budget", message: "Enter a monthly budget greater than zero.")
                return
            }
            let categoryTotal = self.categories.reduce(0) { $0 + $1.budget }
            guard amount >= categoryTotal else {
                self.showAlert(
                    title: "Budget Too Low",
                    message: "Your category limits already add up to \(self.compactCurrency(categoryTotal))."
                )
                return
            }
            DatabaseManager.shared.upsertCurrentBudget(allocatedBudget: amount)
            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
            self.reloadAll()
        })
        present(alert, animated: true)
    }

    private func presentSetLimitPrompt(for category: Category) {
        guard let allocatedBudget = currentBudget?.allocatedBudget, allocatedBudget > 0 else {
            showAlert(title: "Set Monthly Budget First", message: "Add your monthly budget before setting category limits.")
            return
        }

        let alreadyAllocatedByOthers = categories
            .filter { $0.id != category.id }
            .reduce(0) { $0 + $1.budget }
        let maximumAllowed = allocatedBudget - alreadyAllocatedByOthers

        let alert = UIAlertController(
            title: "Set \(category.name) Limit",
            message: "Available: \(compactCurrency(max(maximumAllowed, 0)))",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.keyboardType = .decimalPad
            textField.placeholder = "Amount"
            textField.text = category.budget > 0 ? String(Int(category.budget)) : nil
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            guard let limit = self.parsedAmount(from: alert?.textFields?.first?.text), limit >= 0 else {
                self.showAlert(title: "Invalid Limit", message: "Enter a valid category limit.")
                return
            }
            guard limit <= maximumAllowed else {
                self.showAlert(
                    title: "Limit Too High",
                    message: "This category can use up to \(self.compactCurrency(maximumAllowed))."
                )
                return
            }
            self.saveLimit(limit, for: category)
        })
        present(alert, animated: true)
    }

    private func saveLimit(_ limit: Double, for category: Category) {
        DatabaseManager.shared.updateCategory(
            id: category.id,
            name: category.name,
            color: category.color,
            icon: category.icon,
            budget: limit
        )
        NotificationCenter.default.post(name: .categoryDataDidChange, object: nil)
        NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
        reloadAll()
    }

    private func openEditCategory(category: Category) {
        guard let nav = storyboard?.instantiateViewController(withIdentifier: "EditCategoryNav") as? UINavigationController,
              let vc = nav.viewControllers.first as? EditCategoryViewController else { return }
        vc.category = category
        vc.onCategoryUpdated = { [weak self] in self?.reloadAll() }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    @objc private func addCategoryTapped() {
        guard let nav = storyboard?.instantiateViewController(withIdentifier: "AddCategoryNav") as? UINavigationController,
              let vc = nav.viewControllers.first as? AddCategoryViewController else { return }
        vc.onCategorySaved = { [weak self] in self?.reloadAll() }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    @objc private func addSubsAndBillsTapped() {
        guard let nav = storyboard?.instantiateViewController(withIdentifier: "AddSubsAndBillsNav") as? UINavigationController,
              let vc = nav.viewControllers.first as? AddSubsAndBillsViewController else { return }
        vc.onEntrySaved = { [weak self] in self?.reloadAll() }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    @objc private func addGoalTapped() {
        guard let nav = storyboard?.instantiateViewController(withIdentifier: "AddGoalsNav") as? UINavigationController,
              let vc = nav.viewControllers.first as? AddGoalsViewController else { return }
        vc.onGoalSaved = { [weak self] in self?.reloadAll() }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func openEditSubscription(payment: RecurringPayment) {
        guard let nav = storyboard?.instantiateViewController(withIdentifier: "EditSubsAndBillsNav") as? UINavigationController,
              let vc = nav.viewControllers.first as? EditSubsAndBillsViewController else { return }
        vc.mode = .subscription
        vc.recurringPayment = payment
        vc.onEntryUpdated = { [weak self] in self?.reloadAll() }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func openEditBill(bill: Bill) {
        guard let nav = storyboard?.instantiateViewController(withIdentifier: "EditSubsAndBillsNav") as? UINavigationController,
              let vc = nav.viewControllers.first as? EditSubsAndBillsViewController else { return }
        vc.mode = .bill
        vc.bill = bill
        vc.onEntryUpdated = { [weak self] in self?.reloadAll() }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func openEditGoal(goal: Goal) {
        guard let nav = storyboard?.instantiateViewController(withIdentifier: "EditGoalsNav") as? UINavigationController,
              let vc = nav.viewControllers.first as? EditGoalsViewController else { return }
        vc.goal = goal
        vc.onGoalUpdated = { [weak self] in self?.reloadAll() }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func confirmDelete(title: String, onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(
            title: "Delete \"\(title)\"?",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in onConfirm() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func toggleBillPaymentState(for bill: Bill) {
        let db = DatabaseManager.shared
        let nextPaidState = !bill.isPaid
        db.updateBillPaymentStatus(id: bill.id, isPaid: nextPaidState)
        db.removeBillPaymentTransaction(billId: bill.id)

        if nextPaidState {
            _ = db.insertExpenseTransaction(
                name: bill.name,
                amount: bill.amount,
                timestamp: Date(),
                categoryId: bill.categoryId,
                status: true,
                expenseType: "bill",
                source: .manual,
                note: db.billPaymentNote(for: bill.id)
            )
            BillSubscriptionReminderManager.shared.cancelReminder(forBillId: bill.id)
        } else if let refreshedBill = db.fetchBill(id: bill.id) {
            BillSubscriptionReminderManager.shared.scheduleReminder(for: refreshedBill)
        }

        db.resetMonthlyExpense()
        NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
        NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
        reloadAll()
    }

    private func markSubscriptionAsPaid(_ payment: RecurringPayment) {
        let db = DatabaseManager.shared
        _ = db.insertExpenseTransaction(
            name: payment.name,
            amount: payment.amount,
            timestamp: payment.nextDate,
            categoryId: payment.categoryId,
            status: true,
            expenseType: "subscription",
            source: .manual,
            note: "subscription-payment:\(payment.id.uuidString)"
        )

        let nextDate = advancedDate(from: payment.nextDate, duration: payment.duration)
        db.updateRecurringPayment(
            id: payment.id,
            name: payment.name,
            duration: payment.duration,
            amount: payment.amount,
            nextDate: nextDate,
            isAlertEnabled: payment.isAlertEnabled,
            isAddAutomatically: payment.isAddAutomatically,
            isActive: payment.isActive,
            note: payment.note
        )
        NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
        NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
        reloadAll()
    }

    private func canMarkBillAsPaid(_ bill: Bill) -> Bool {
        guard !bill.isPaid else { return false }
        return isWithinPaymentWindow(bill.billDate)
    }

    private func canMarkSubscriptionAsPaid(_ payment: RecurringPayment) -> Bool {
        isWithinPaymentWindow(payment.nextDate)
    }

    private func isWithinPaymentWindow(_ dueDate: Date) -> Bool {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let paymentWindowEnd = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
        return calendar.startOfDay(for: dueDate) <= paymentWindowEnd
    }

    private func advancedDate(from date: Date, duration: PaymentDuration) -> Date {
        let calendar = Calendar.current
        switch duration {
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly: return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .halfYearly: return calendar.date(byAdding: .month, value: 6, to: date) ?? date
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }

    @objc private func showProfile() {
        guard let profile = storyboard?.instantiateViewController(withIdentifier: "ProfileViewController") else { return }
        navigationController?.pushViewController(profile, animated: true)
    }

    @objc private func handleDataChange() {
        reloadAll()
    }

    private func parsedAmount(from text: String?) -> Double? {
        let cleaned = (text ?? "").filter { $0.isNumber || $0 == "." }
        guard cleaned.filter({ $0 == "." }).count <= 1 else { return nil }
        return Double(cleaned)
    }

    private func compactCurrency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func allowContextMenuPreviewOverflow(for collectionView: UICollectionView) {
        var currentView: UIView? = collectionView
        while let view = currentView, !(view is UIScrollView && view !== collectionView) {
            view.clipsToBounds = false
            view.layer.masksToBounds = false
            currentView = view.superview
        }
    }

}

extension NewBudgetViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == categoriesCollectionView { return categories.count }
        if collectionView == subsAndBillsCollectionView { return subsAndBillsItems.count }
        return goals.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == categoriesCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CategoryCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as! CategoryCollectionViewCell
            cell.configure(with: categoryItem(for: categories[indexPath.item]))
            return cell
        }

        if collectionView == subsAndBillsCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: BillCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as! BillCollectionViewCell
            cell.configure(with: billItem(for: subsAndBillsItems[indexPath.item]))
            return cell
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: GoalCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! GoalCollectionViewCell
        cell.configure(with: goalItem(for: goals[indexPath.item]))
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        if collectionView == categoriesCollectionView {
            let width = (collectionView.bounds.width - 18) / 2
            return CGSize(width: max(width, 0), height: 132)
        }
        if collectionView == subsAndBillsCollectionView {
            return BillCollectionViewCell.itemSize
        }
        return CGSize(width: collectionView.bounds.width, height: 86)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        collectionView == goalsCollectionView ? 14 : 18
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        18
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        if collectionView == categoriesCollectionView {
            guard categories.indices.contains(indexPath.item) else { return nil }
            let category = categories[indexPath.item]
            return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { [weak self] _ in
                let setLimit = UIAction(title: "Set Limit", image: UIImage(systemName: "slider.horizontal.3")) { _ in
                    self?.presentSetLimitPrompt(for: category)
                }
                let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in
                    self?.openEditCategory(category: category)
                }
                let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                    self?.confirmDelete(title: category.name) {
                        DatabaseManager.shared.deleteCategory(id: category.id)
                        NotificationCenter.default.post(name: .categoryDataDidChange, object: nil)
                        NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
                        self?.reloadAll()
                    }
                }
                return UIMenu(title: category.name, children: [setLimit, edit, delete])
            }
        }

        if collectionView == subsAndBillsCollectionView {
            guard subsAndBillsItems.indices.contains(indexPath.item) else { return nil }
            let item = subsAndBillsItems[indexPath.item]
            return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { [weak self] _ in
                switch item {
                case .subscription(let payment):
                    let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in
                        self?.openEditSubscription(payment: payment)
                    }
                    let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                        self?.confirmDelete(title: payment.name) {
                            BillSubscriptionReminderManager.shared.cancelReminder(forSubscriptionId: payment.id)
                            DatabaseManager.shared.deleteRecurringPayment(id: payment.id)
                            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
                            self?.reloadAll()
                        }
                    }
                    var actions: [UIMenuElement] = []
                    if self?.canMarkSubscriptionAsPaid(payment) == true {
                        actions.append(UIAction(title: "Mark as Paid", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                            self?.markSubscriptionAsPaid(payment)
                        })
                    }
                    actions.append(contentsOf: [edit, delete])
                    return UIMenu(title: payment.name, children: actions)
                case .bill(let bill):
                    let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in
                        self?.openEditBill(bill: bill)
                    }
                    let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                        self?.confirmDelete(title: bill.name) {
                            BillSubscriptionReminderManager.shared.cancelReminder(forBillId: bill.id)
                            DatabaseManager.shared.deleteBill(id: bill.id)
                            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
                            self?.reloadAll()
                        }
                    }
                    var actions: [UIMenuElement] = []
                    if self?.canMarkBillAsPaid(bill) == true {
                        actions.append(UIAction(title: "Mark as Paid", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                            self?.toggleBillPaymentState(for: bill)
                        })
                    }
                    actions.append(contentsOf: [edit, delete])
                    return UIMenu(title: bill.name, children: actions)
                }
            }
        }

        guard goals.indices.contains(indexPath.item) else { return nil }
        let goal = goals[indexPath.item]
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { [weak self] _ in
            let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in
                self?.openEditGoal(goal: goal)
            }
                let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                    self?.confirmDelete(title: goal.name) {
                        DatabaseManager.shared.deleteGoal(id: goal.id)
                        GoalImageStore.removeImage(for: goal.id)
                        NotificationCenter.default.post(name: .goalDataDidChange, object: nil)
                        NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
                        self?.reloadAll()
                    }
                }
            return UIMenu(title: goal.name, children: [edit, delete])
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        contextMenuPreview(for: collectionView, configuration: configuration)
    }

    func collectionView(_ collectionView: UICollectionView,
                        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        contextMenuPreview(for: collectionView, configuration: configuration)
    }

    func collectionView(_ collectionView: UICollectionView,
                        willEndContextMenuInteraction configuration: UIContextMenuConfiguration,
                        animator: (any UIContextMenuInteractionAnimating)?) {
        animator?.addCompletion { [weak self, weak collectionView] in
            guard let self, let collectionView else { return }
            self.resetContextMenuCells(in: collectionView)
        }
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

private extension NewBudgetViewController {
    func contextMenuPreview(
        for collectionView: UICollectionView,
        configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? NSIndexPath else { return nil }

        let previewView: UIView
        if collectionView == categoriesCollectionView,
           let cell = collectionView.cellForItem(at: indexPath as IndexPath) as? CategoryCollectionViewCell {
            previewView = cell.contextMenuPreviewView
        } else if collectionView == subsAndBillsCollectionView,
                  let cell = collectionView.cellForItem(at: indexPath as IndexPath) as? BillCollectionViewCell {
            previewView = cell.contextMenuPreviewView
        } else if collectionView == goalsCollectionView,
                  let cell = collectionView.cellForItem(at: indexPath as IndexPath) as? GoalCollectionViewCell {
            previewView = cell.contextMenuPreviewView
        } else {
            return nil
        }

        guard previewView.window != nil,
              let previewSuperview = previewView.superview,
              !previewView.bounds.isEmpty
        else { return nil }

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(
            roundedRect: previewView.bounds,
            cornerRadius: previewView.layer.cornerRadius
        )

        let targetCenter = previewSuperview.convert(
            CGPoint(x: previewView.frame.midX, y: previewView.frame.midY),
            to: view
        )
        let target = UIPreviewTarget(container: view, center: targetCenter)
        return UITargetedPreview(view: previewView, parameters: parameters, target: target)
    }

    func resetContextMenuCells(in collectionView: UICollectionView) {
        collectionView.visibleCells.forEach { cell in
            if let categoryCell = cell as? CategoryCollectionViewCell {
                categoryCell.resetContextMenuState()
            } else if let billCell = cell as? BillCollectionViewCell {
                billCell.resetContextMenuState()
            } else if let goalCell = cell as? GoalCollectionViewCell {
                goalCell.resetContextMenuState()
            }

            cell.layer.zPosition = 0
            cell.transform = .identity
            cell.contentView.transform = .identity
        }
    }
}
