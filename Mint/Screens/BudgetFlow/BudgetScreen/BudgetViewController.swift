
import UIKit

enum SubsOrBillItem {
    case subscription(RecurringPayment)
    case bill(Bill)
}

class BudgetViewController: UIViewController, UICollectionViewDelegate {

    private enum LayoutMetrics {
        static let compactListSpacing: CGFloat = 12
        static let compactCellHeight: CGFloat = 56
        static let compactGoalCellHeight: CGFloat = 88
        static let placeholderCellHeight: CGFloat = 88
    }

    private enum EmptyStateMessage {
        static let categories = "Your budget categories will be visible here."
        static let subsAndBills = "Your subscriptions and bills will be visible here."
        static let goals = "Your budget goals will be visible here."
    }

    private var hasCheckedOnboarding = false

    @IBOutlet var AllViewCards: [UIView]!

    @IBOutlet weak var monthlyBudgetView: UIView!
    @IBOutlet weak var MonthlyBudgetLabel: UILabel!
    @IBOutlet weak var BudgetAmountLabel: UILabel!
    @IBOutlet weak var BudgetEditButton: UIButton!

    @IBOutlet weak var sumOfCategories: UILabel!
    @IBOutlet weak var totalBudget: UILabel!
    @IBOutlet weak var goalsStackView: UIStackView!
    @IBOutlet weak var subsAndBillsStackView: UIStackView!
    @IBOutlet weak var categoriesStackView: UIStackView!
    @IBOutlet weak var CardsHeadingView: UIView!
    @IBOutlet weak var CardsTitleLabel: UILabel!
    @IBOutlet weak var AddCategoryButton: UIButton!

    @IBOutlet weak var AddSubsandBillsButton: UIButton!
    @IBOutlet weak var AddGoalsButton: UIButton!

    @IBOutlet weak var newBudgetTextField: UITextField!
    @IBOutlet weak var CategoriesCollectionView: UICollectionView!
    @IBOutlet weak var SubsandBillsCollectionView: UICollectionView!
    @IBOutlet weak var GoalsCollectionView: UICollectionView!

    @IBOutlet weak var CategoriesPageControl: UIPageControl!
    @IBOutlet weak var SubsandBillsPageControl: UIPageControl!
    @IBOutlet weak var GoalsPageControl: UIPageControl!

    @IBOutlet weak var newBudgetView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!

    private var categories:        [Category]         = []
    private var goals:             [Goal]              = []
    private var recurringPayments: [RecurringPayment]  = []
    private var bills:             [Bill]              = []
    private var currentBudget:     Budget?

    private var subsAndBillsItems: [SubsOrBillItem] = []

    private let itemsPerPage = 4
    private let goalsItemsPerPage = 2
    private var spotlightView: OnboardingSpotlightView?
    private var currentOnboardingStep = 0
    private var onboardingSteps: [OnboardingStep] = []

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        reloadAll()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        newBudgetView.isHidden = true
        setupUI()
        setupPageControls()
        setupCollectionViews()
        
        
        // jab bhi data change ho - call this
        NotificationCenter.default.addObserver(
            self, // current view ocntroller
            selector: #selector(handleCategoryDataChange), // method to call
            name: .categoryDataDidChange, //notification identifier
            object: nil // listen from any sender
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTransactionDataChange),
            name: .transactionDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBudgetDataChange),
            name: .goalDataDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBudgetDataChange),
            name: .budgetDataDidChange,
            object: nil
        )

        onboardingSteps = [
            OnboardingStep(
                view: monthlyBudgetView,
                title: "Monthly Budget",
                message: "This is your total budget for the month. Tap edit to adjust it anytime.",
                tooltipBelow: true
            ),
            OnboardingStep(
                view: categoriesStackView,
                title: "Spending Categories",
                message: "Organise your spending into categories to see where your money goes.",
                tooltipBelow: true
            ),
            OnboardingStep(
                view: subsAndBillsStackView,
                title: "Subscriptions & Bills",
                message: "Track all your recurring payments and upcoming bills in one place.",
                tooltipBelow: false
            ),
            OnboardingStep(
                view: goalsStackView,
                title: "Savings Goals",
                message: "Set goals and watch your progress grow over time.",
                tooltipBelow: false
            ),
        ]
    }

    var isExpanded = false
        private var hasEdited = false

        private func setBudgetButtonTitle(_ title: String) {
            if BudgetEditButton.configuration != nil {
                BudgetEditButton.configuration?.title = title
            } else {
                BudgetEditButton.setTitle(title, for: .normal)
            }
        }
     
        @IBAction func editButtonTapped(_ sender: UIButton) {
            let currentTitle = sender.configuration?.title ?? sender.title(for: .normal)
     
            if currentTitle == "Save" {
                guard let text = newBudgetTextField.text,
                      let amount = Double(text), amount > 0 else {
                    collapseEditView()
                    return
                }
                DatabaseManager.shared.updateBudgetSettings(allocatedBudget: amount)
                NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
                collapseEditView()
     
            } else if currentTitle == "Cancel" {
                collapseEditView()
     
            } else {
                isExpanded = true
                hasEdited = false
                newBudgetView.isHidden = false
                setBudgetButtonTitle("Cancel")
                newBudgetTextField.text = ""
                newBudgetTextField.becomeFirstResponder()
            }
        }
     
        private func collapseEditView() {
            isExpanded = false
            hasEdited = false
            newBudgetView.isHidden = true
            newBudgetTextField.text = ""
            newBudgetTextField.resignFirstResponder()
            setBudgetButtonTitle("Edit")
        }
     
        @objc private func budgetTextFieldChanged(_ sender: UITextField) {
            let hasText = !(sender.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
            if hasText && !hasEdited {
                hasEdited = true
                setBudgetButtonTitle("Save")
            } else if !hasText && hasEdited {
                hasEdited = false
                setBudgetButtonTitle("Cancel")
            }
        }
     
        @IBAction func newBudetInput(_ sender: Any) {}
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionLayouts()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasCheckedOnboarding else { return }
        hasCheckedOnboarding = true

        if OnboardingHelper.shouldShow(key: OnboardingKeys.budget) {
            showBudgetOnboarding()
            OnboardingHelper.markSeen(key: OnboardingKeys.budget)
        }
    }

    private func loadDataFromDatabase() {
        let db = DatabaseManager.shared

        categories        = db.fetchCategories()
        goals             = db.fetchGoals()
        recurringPayments = db.fetchRecurringPayments()
        bills             = db.fetchUpcomingBills()
        currentBudget     = db.fetchCurrentBudget()

        buildSubsAndBillsList()
        updateBudgetLabel()
    }

    private func updateBudgetLabel() {
        if let budget = currentBudget {
            BudgetAmountLabel.text = currencyFormatter.string(
                from: NSNumber(value: budget.allocatedBudget)
            ) ?? "₹0"
        } else {
            BudgetAmountLabel.text = "₹0"
        }
        updateCategoryBudgetSummary()
    }

    private func updateCategoryBudgetSummary() {
        let categorySum    = categories.reduce(0) { $0 + $1.budget }
        let allocatedTotal = currentBudget?.allocatedBudget ?? 0

        sumOfCategories.text = currencyFormatter.string(from: NSNumber(value: categorySum)) ?? "₹0"
        totalBudget.text     = currencyFormatter.string(from: NSNumber(value: allocatedTotal)) ?? "₹0"

        totalBudget.textColor = AppColors.textSecondary
        sumOfCategories.textColor = categorySum > allocatedTotal ? .systemRed : AppColors.textSecondary
    }

    private func reloadAll() {
        loadDataFromDatabase()
        setupPageControls()
        updateCollectionLayouts()
        CategoriesCollectionView.reloadData()
        SubsandBillsCollectionView.reloadData()
        GoalsCollectionView.reloadData()
    }

    private func buildSubsAndBillsList() {
        let calendar     = Calendar.current
        let now          = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear  = calendar.component(.year,  from: now)
     
        var items: [SubsOrBillItem] = []
     
        for payment in recurringPayments.reversed() {
            items.append(.subscription(payment))
        }
     
        for bill in bills {
            let billMonth = calendar.component(.month, from: bill.billDate)
            let billYear  = calendar.component(.year,  from: bill.billDate)
            guard billMonth == currentMonth && billYear == currentYear else { continue }
            items.append(.bill(bill))
        }
     
        subsAndBillsItems = items
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let nav = segue.destination as? UINavigationController else { return }

        switch segue.identifier {

        case "showAddCategory":
            if let vc = nav.viewControllers.first as? AddCategoryViewController {
                vc.onCategorySaved = { [weak self] in self?.reloadAll() }
            }

        case "showAddSubsAndBills":
            if let vc = nav.viewControllers.first as? AddSubsAndBillsViewController {
                vc.onEntrySaved = { [weak self] in self?.reloadAll() }
            }

        case "showAddGoals":
            if let vc = nav.viewControllers.first as? AddGoalsViewController {
                vc.onGoalSaved = { [weak self] in self?.reloadAll() }
            }

        default:
            break
        }
    }

    private func openEditCategory(category: Category) {
        guard
            let nav = storyboard?.instantiateViewController(withIdentifier: "EditCategoryNav") as? UINavigationController,
            let vc  = nav.viewControllers.first as? EditCategoryViewController
        else { return }

        vc.category          = category
        vc.onCategoryUpdated = { [weak self] in self?.reloadAll() }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func openEditSubscription(payment: RecurringPayment) {
        guard
            let nav = storyboard?.instantiateViewController(withIdentifier: "EditSubsAndBillsNav") as? UINavigationController,
            let vc  = nav.viewControllers.first as? EditSubsAndBillsViewController
        else { return }

        vc.mode             = .subscription
        vc.recurringPayment = payment
        vc.onEntryUpdated   = { [weak self] in self?.reloadAll() }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func openEditBill(bill: Bill) {
        guard
            let nav = storyboard?.instantiateViewController(withIdentifier: "EditSubsAndBillsNav") as? UINavigationController,
            let vc  = nav.viewControllers.first as? EditSubsAndBillsViewController
        else { return }

        vc.mode           = .bill
        vc.bill           = bill
        vc.onEntryUpdated = { [weak self] in self?.reloadAll() }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func openEditGoal(goal: Goal) {
        guard
            let nav = storyboard?.instantiateViewController(withIdentifier: "EditGoalsNav") as? UINavigationController,
            let vc  = nav.viewControllers.first as? EditGoalsViewController
        else { return }

        vc.goal          = goal
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

    private func showBudgetOnboarding() { startOnboarding() }

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

        let frameInView  = step.view.convert(step.view.bounds, to: self.view)
        let screenHeight = self.view.bounds.height
        let topPadding: CGFloat    = 60
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

            let frameInScroll       = step.view.convert(step.view.bounds, to: scrollView)
            let idealOffset         = frameInScroll.midY - (screenHeight / 2)
            let maxOffset           = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            var finalOffset         = max(0, min(idealOffset, maxOffset))

            let viewBottomInContent = frameInScroll.maxY
            let visibleBottomAtOffset = finalOffset + screenHeight - bottomPadding
            if viewBottomInContent > visibleBottomAtOffset {
                finalOffset = min(viewBottomInContent - screenHeight + bottomPadding + 20, maxOffset)
            }

            scrollView.setContentOffset(CGPoint(x: 0, y: finalOffset), animated: true)

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
            self.scrollView.setContentOffset(.zero, animated: true)
        })
    }

    private func setupPageControls() {
            let categoriesPages = categories.isEmpty ? 0 : Int(ceil(Double(categories.count) / Double(itemsPerPage)))
            let paymentsPages   = subsAndBillsItems.isEmpty ? 0 : Int(ceil(Double(subsAndBillsItems.count) / Double(itemsPerPage)))
            let goalsPages      = goals.isEmpty ? 0 : Int(ceil(Double(goals.count) / Double(goalsItemsPerPage)))
     
            CategoriesPageControl.numberOfPages   = categoriesPages
            SubsandBillsPageControl.numberOfPages = paymentsPages
            GoalsPageControl.numberOfPages        = goalsPages
     
            [CategoriesPageControl, SubsandBillsPageControl, GoalsPageControl].forEach {
                $0?.currentPage                   = 0
                $0?.currentPageIndicatorTintColor = AppColors.brand
                $0?.pageIndicatorTintColor        = AppColors.brand.withAlphaComponent(0.3)
                $0?.isUserInteractionEnabled      = false
            }

            CategoriesPageControl.isHidden = categoriesPages <= 1
            SubsandBillsPageControl.isHidden = paymentsPages <= 1
            GoalsPageControl.isHidden = goalsPages <= 1
        }

    private func setupCollectionViews() {
            registerPlaceholderCell(for: CategoriesCollectionView)
            CategoriesCollectionView.register(
                UINib(nibName: "BudgetCategoriesCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: "BudgetCategoriesCell"
            )
            CategoriesCollectionView.delegate   = self
            CategoriesCollectionView.dataSource = self
     
            registerPlaceholderCell(for: SubsandBillsCollectionView)
            SubsandBillsCollectionView.register(
                UINib(nibName: "BudgetSubsandBillsCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: "BudgetSubsandBillsCell"
            )
            SubsandBillsCollectionView.delegate   = self
            SubsandBillsCollectionView.dataSource = self
     
            registerPlaceholderCell(for: GoalsCollectionView)
            GoalsCollectionView.register(
                UINib(nibName: "BudgetGoalsCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: "BudgetGoalsCell"
            )
            GoalsCollectionView.delegate   = self
            GoalsCollectionView.dataSource = self

            updateCollectionLayouts()
        }

        private func registerPlaceholderCell(for collectionView: UICollectionView) {
            collectionView.register(
                UINib(nibName: PlaceHolderCollectionViewCell.nibName, bundle: nil),
                forCellWithReuseIdentifier: PlaceHolderCollectionViewCell.reuseIdentifier
            )
        }

        private func updateCollectionLayouts() {
            CategoriesCollectionView.collectionViewLayout = makeDynamicLayout(
                itemCount: max(categories.count, 1),
                cellHeight: categories.isEmpty ? LayoutMetrics.placeholderCellHeight : LayoutMetrics.compactCellHeight,
                pageControl: CategoriesPageControl
            )
            SubsandBillsCollectionView.collectionViewLayout = makeDynamicLayout(
                itemCount: max(subsAndBillsItems.count, 1),
                cellHeight: subsAndBillsItems.isEmpty ? LayoutMetrics.placeholderCellHeight : LayoutMetrics.compactCellHeight,
                pageControl: SubsandBillsPageControl
            )
            GoalsCollectionView.collectionViewLayout = makeDynamicLayout(
                itemCount: max(goals.count, 1),
                cellHeight: goals.isEmpty ? LayoutMetrics.placeholderCellHeight : LayoutMetrics.compactGoalCellHeight,
                pageControl: GoalsPageControl,
                itemsPerPage: goalsItemsPerPage
            )
        }

        private func makeDynamicLayout(itemCount: Int,
                                       cellHeight: CGFloat,
                                       pageControl: UIPageControl,
                                       itemsPerPage: Int? = nil) -> UICollectionViewLayout {
            let perPage = itemsPerPage ?? self.itemsPerPage
            if itemCount <= perPage {
                return makeStaticVerticalLayout(itemCount: itemCount, cellHeight: cellHeight)
            }

            return generateHorizontalPageLayout(
                itemsPerPage: perPage,
                cellHeight: cellHeight,
                pageControl: pageControl
            )
        }

        private func makeStaticVerticalLayout(itemCount: Int,
                                              cellHeight: CGFloat) -> UICollectionViewLayout {
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(cellHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let estimatedHeight = (CGFloat(itemCount) * cellHeight) + (CGFloat(max(itemCount - 1, 0)) * LayoutMetrics.compactListSpacing)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(estimatedHeight)
            )
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: itemCount
            )
            group.interItemSpacing = .fixed(LayoutMetrics.compactListSpacing)

            let section = NSCollectionLayoutSection(group: group)
            return UICollectionViewCompositionalLayout(section: section)
        }

        private func generateHorizontalPageLayout(itemsPerPage: Int,
                                                   cellHeight: CGFloat,
                                                   pageControl: UIPageControl) -> UICollectionViewLayout {
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(cellHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
     
            let spacing: CGFloat     = LayoutMetrics.compactListSpacing
            let groupHeight: CGFloat = (cellHeight * CGFloat(itemsPerPage)) + (spacing * CGFloat(itemsPerPage - 1))
     
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(groupHeight)
            )
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: itemsPerPage
            )
            group.interItemSpacing = .fixed(spacing)
     
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .groupPaging
            section.visibleItemsInvalidationHandler = { _, contentOffset, environment in
                let pageWidth    = environment.container.effectiveContentSize.width
                let currentPage  = Int(round(contentOffset.x / pageWidth))
                pageControl.currentPage = currentPage
            }
     
            return UICollectionViewCompositionalLayout(section: section)
        }
     
     

    func setupUI() {
        view.backgroundColor = AppColors.background
        AllViewCards.forEach { $0.backgroundColor = AppColors.background }
        MonthlyBudgetLabel.textColor = AppColors.textSecondary
        BudgetAmountLabel.textColor  = AppColors.textPrimary

        CardsHeadingView.backgroundColor = AppColors.background
        CardsTitleLabel.textColor        = AppColors.textSecondary
        BudgetEditButton.tintColor       = AppColors.brand
        BudgetEditButton.setTitleColor(AppColors.brandText, for: .normal)

        let footnoteFont = UIFont.preferredFont(forTextStyle: .footnote)
        if var config = BudgetEditButton.configuration {
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var attrs = incoming
                attrs.font = footnoteFont
                return attrs
            }
            BudgetEditButton.configuration = config
        } else {
            BudgetEditButton.titleLabel?.font = footnoteFont
        }
        
        newBudgetTextField.keyboardType = .decimalPad
        newBudgetTextField.addTarget(self,
                                     action: #selector(budgetTextFieldChanged(_:)),
                                     for: .editingChanged)

        AddCategoryButton.tintColor      = AppColors.brand
        AddCategoryButton.setTitleColor(AppColors.brandText, for: .normal)
        AddSubsandBillsButton.tintColor  = AppColors.brand
        AddSubsandBillsButton.setTitleColor(AppColors.brandText, for: .normal)
        AddGoalsButton.tintColor         = AppColors.brand
        AddGoalsButton.setTitleColor(AppColors.brandText, for: .normal)

        CategoriesCollectionView.backgroundColor   = AppColors.background
        SubsandBillsCollectionView.backgroundColor = AppColors.background
        GoalsCollectionView.backgroundColor        = AppColors.background
    }

    @objc private func handleCategoryDataChange() {
        reloadAll()
    }

    @objc private func handleTransactionDataChange() {
        reloadAll()
    }

    @objc private func handleBudgetDataChange() {
        reloadAll()
    }

    private func isShowingPlaceholder(in collectionView: UICollectionView) -> Bool {
        if collectionView == CategoriesCollectionView {
            return categories.isEmpty
        } else if collectionView == SubsandBillsCollectionView {
            return subsAndBillsItems.isEmpty
        } else {
            return goals.isEmpty
        }
    }

    private func placeholderMessage(for collectionView: UICollectionView) -> String {
        if collectionView == CategoriesCollectionView {
            return EmptyStateMessage.categories
        } else if collectionView == SubsandBillsCollectionView {
            return EmptyStateMessage.subsAndBills
        } else {
            return EmptyStateMessage.goals
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
        cell.configure(
            message: placeholderMessage(for: collectionView),
            sizeStyle: .compact
        )
        return cell
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension BudgetViewController: UICollectionViewDataSource {
 
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView == CategoriesCollectionView {
            return max(categories.count, 1)
        } else if collectionView == SubsandBillsCollectionView {
            return max(subsAndBillsItems.count, 1)
        } else {
            return max(goals.count, 1)
        }
    }
 
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        if isShowingPlaceholder(in: collectionView) {
            return dequeuePlaceholderCell(in: collectionView, for: indexPath)
        }
 
        if collectionView == CategoriesCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "BudgetCategoriesCell", for: indexPath
            ) as! BudgetCategoriesCollectionViewCell
            cell.configureCategoryCell(category: categories[indexPath.item])
            return cell
 
        } else if collectionView == SubsandBillsCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BudgetSubsandBillsCell", for: indexPath) as! BudgetSubsandBillsCollectionViewCell
 
            switch subsAndBillsItems[indexPath.item] {
            case .subscription(let payment):
                cell.configure(RecurringPayment: payment)
            case .bill(let bill):
                cell.configureBill(bill: bill)
            }
            return cell
 
        } else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "BudgetGoalsCell", for: indexPath
            ) as! BudgetGoalsCollectionViewCell
            cell.configure(goal: goals[indexPath.item])
            return cell
        }
    }
}

extension BudgetViewController {
 
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
 
        if collectionView == CategoriesCollectionView {
            guard !categories.isEmpty else { return nil }
            let category = categories[indexPath.item]
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in
                    self?.openEditCategory(category: category)
                }
                let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"),
                                      attributes: .destructive) { [weak self] _ in
                    self?.confirmDelete(title: category.name) {
                        DatabaseManager.shared.deleteCategory(id: category.id)
                        NotificationCenter.default.post(name: .categoryDataDidChange, object: nil)
                        NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
                        self?.reloadAll()
                    }
                }
                return UIMenu(title: category.name, children: [edit, delete])
            }
 
        } else if collectionView == SubsandBillsCollectionView {
            guard !subsAndBillsItems.isEmpty else { return nil }
            let item = subsAndBillsItems[indexPath.item]
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                switch item {
                case .subscription(let payment):
                    let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in
                        self?.openEditSubscription(payment: payment)
                    }
                    let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"),
                                          attributes: .destructive) { [weak self] _ in
                        self?.confirmDelete(title: payment.name) {
                            DatabaseManager.shared.deleteRecurringPayment(id: payment.id)
                            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
                            self?.reloadAll()
                        }
                    }
                    return UIMenu(title: payment.name, children: [edit, delete])
 
                case .bill(let bill):
                    let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in
                        self?.openEditBill(bill: bill)
                    }
                    let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"),
                                          attributes: .destructive) { [weak self] _ in
                        self?.confirmDelete(title: bill.name) {
                            DatabaseManager.shared.deleteBill(id: bill.id)
                            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
                            self?.reloadAll()
                        }
                    }
                    return UIMenu(title: bill.name, children: [edit, delete])
                }
            }
 
        } else {
            guard !goals.isEmpty else { return nil }
            let goal = goals[indexPath.item]
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { _ in
                    self?.openEditGoal(goal: goal)
                }
                let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"),
                                      attributes: .destructive) { [weak self] _ in
                    self?.confirmDelete(title: goal.name) {
                        DatabaseManager.shared.deleteGoal(id: goal.id)
                        NotificationCenter.default.post(name: .goalDataDidChange, object: nil)
                        NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
                        self?.reloadAll()
                    }
                }
                return UIMenu(title: goal.name, children: [edit, delete])
            }
        }
    }
}
