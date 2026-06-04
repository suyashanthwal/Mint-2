import UIKit

private enum GoalsSection: Int, CaseIterable {
    case badges
    case active
    case addGoal
    case completed
    case inactive

    var title: String {
        switch self {
        case .badges:
            return "BADGES EARNED"
        case .active:
            return "ACTIVE GOALS"
        case .addGoal:
            return ""
        case .completed:
            return "COMPLETE GOALS"
        case .inactive:
            return "INACTIVE GOALS"
        }
    }
}

final class GoalsViewController: UIViewController {

    @IBOutlet private weak var headerContainerView: UIView!
    @IBOutlet private weak var goalsCollectionView: UICollectionView!
    
    @IBOutlet private weak var profileButton: UIButton!
    

    private var hasCheckedOnboarding = false
    private var allGoals: [Goal] = []
    private var badgeGoals: [Goal] = []
    private var activeGoals: [Goal] = []
    private var completedGoals: [Goal] = []
    private var inactiveGoals: [Goal] = []

    private var spotlightView: OnboardingSpotlightView?
    private var currentOnboardingStep = 0
    private var onboardingSteps: [OnboardingStep] = []
    private var touchFeedbackRecognizer: UILongPressGestureRecognizer?
    private var touchFeedbackIndexPath: IndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        registerReusableViews()
        configureCollectionView()
        configureOnboarding()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGoalDataChange),
            name: .goalDataDidChange,
            object: nil
        )

        reloadGoals()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        reloadGoals()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasCheckedOnboarding else { return }
        hasCheckedOnboarding = true

        if OnboardingHelper.shouldShow(key: OnboardingKeys.goals) {
            showGoalsOnboarding()
            OnboardingHelper.markSeen(key: OnboardingKeys.goals)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        view.backgroundColor = AppColors.background
        headerContainerView.backgroundColor = .clear
        goalsCollectionView.backgroundColor = .clear
        
        profileButton.tintColor = AppColors.background
        profileButton.backgroundColor = AppColors.textPrimary
        profileButton.layer.cornerRadius = 17
        profileButton.addTarget(self, action: #selector(showProfile), for: .touchUpInside)
        
        
    }

    private func registerReusableViews() {
        goalsCollectionView.register(
            UINib(nibName: "GoalBadgeCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "GoalBadgeCollectionViewCell"
        )
        goalsCollectionView.register(
            UINib(nibName: "OngoingGoalCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "OngoingGoalCollectionViewCell"
        )
        goalsCollectionView.register(
            UINib(nibName: "GoalAddButtonCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "GoalAddButtonCollectionViewCell"
        )
        goalsCollectionView.register(
            UINib(nibName: "ReachedGoalsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "ReachedGoalsCollectionViewCell"
        )
        goalsCollectionView.register(
            UINib(nibName: PlaceHolderCollectionViewCell.nibName, bundle: nil),
            forCellWithReuseIdentifier: PlaceHolderCollectionViewCell.reuseIdentifier
        )
        goalsCollectionView.register(
            UINib(nibName: "GoalsSectionHeaderReusableView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: GoalsSectionHeaderReusableView.reuseIdentifier
        )
    }

    private func configureCollectionView() {
        goalsCollectionView.collectionViewLayout = makeLayout()
        goalsCollectionView.delegate = self
        goalsCollectionView.dataSource = self
        goalsCollectionView.showsVerticalScrollIndicator = false
        goalsCollectionView.alwaysBounceVertical = true
        goalsCollectionView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 40, right: 0)

        let touchFeedbackRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleTouchFeedbackPress(_:))
        )
        touchFeedbackRecognizer.minimumPressDuration = 0
        touchFeedbackRecognizer.cancelsTouchesInView = false
        touchFeedbackRecognizer.delegate = self
        goalsCollectionView.addGestureRecognizer(touchFeedbackRecognizer)
        self.touchFeedbackRecognizer = touchFeedbackRecognizer
    }

    private func configureOnboarding() {
        onboardingSteps = [
            OnboardingStep(
                view: headerContainerView,
                title: "Goals",
                message: "Track the items you are saving for and jump into the details from here.",
                tooltipBelow: true
            ),
            OnboardingStep(
                view: goalsCollectionView,
                title: "Goal Board",
                message: "Badges, active goals, completed purchases, and inactive goals all live in one place now.",
                tooltipBelow: false
            )
        ]
    }

    private func reloadGoals() {
        allGoals = DatabaseManager.shared.fetchGoals()
        GoalImageStore.attachSavedImages(to: &allGoals)

        activeGoals = allGoals
            .filter(\.isActiveGoal)
            .sorted { lhs, rhs in
                if lhs.isReadyToPurchase != rhs.isReadyToPurchase {
                    return lhs.isReadyToPurchase && !rhs.isReadyToPurchase
                }
                return lhs.targetDate < rhs.targetDate
            }

        completedGoals = allGoals
            .filter(\.isCompleted)
            .sorted { ($0.completedOn ?? .distantPast) > ($1.completedOn ?? .distantPast) }

        badgeGoals = completedGoals

        inactiveGoals = allGoals
            .filter { !$0.isCompleted && $0.isOnHold }
            .sorted { $0.targetDate < $1.targetDate }

        guard isViewLoaded else { return }
        goalsCollectionView.collectionViewLayout.invalidateLayout()
        goalsCollectionView.reloadData()
    }

    private func placeholderMessage(for section: GoalsSection) -> String {
        switch section {
        case .badges:
            return "Completed goals will earn badges here."
        case .active:
            return "Your active goals will show up here."
        case .completed:
            return "Purchased goals will appear here."
        case .inactive:
            return "Goals you put on hold will appear here."
        case .addGoal:
            return ""
        }
    }

    private func placeholderStyle(for section: GoalsSection) -> PlaceHolderCollectionViewCell.SizeStyle {
        switch section {
        case .completed:
            return .compact
        case .badges, .active, .inactive:
            return .fill
        case .addGoal:
            return .compact
        }
    }

    private func countText(for section: GoalsSection) -> String {
        switch section {
        case .badges:
            return "\(badgeGoals.count) EARNED"
        case .active:
            return "\(activeGoals.count) ACTIVE"
        case .addGoal:
            return ""
        case .completed:
            return "\(completedGoals.count) DONE"
        case .inactive:
            return "\(inactiveGoals.count) HOLD"
        }
    }

    private func sectionGoals(for section: GoalsSection) -> [Goal] {
        switch section {
        case .badges:
            return badgeGoals
        case .active:
            return activeGoals
        case .completed:
            return completedGoals
        case .inactive:
            return inactiveGoals
        case .addGoal:
            return []
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self, let section = GoalsSection(rawValue: sectionIndex) else { return nil }

            switch section {
            case .badges:
                return self.makeBadgesSectionLayout(isEmpty: self.badgeGoals.isEmpty)
            case .active:
                return self.makeHeroSectionLayout(showHeader: true, isEmpty: self.activeGoals.isEmpty)
            case .addGoal:
                return self.makeAddButtonLayout()
            case .completed:
                return self.makeCompletedSectionLayout(isEmpty: self.completedGoals.isEmpty)
            case .inactive:
                return self.makeHeroSectionLayout(showHeader: true, isEmpty: self.inactiveGoals.isEmpty)
            }
        }
    }

    private func makeBadgesSectionLayout(isEmpty: Bool) -> NSCollectionLayoutSection {
        let section: NSCollectionLayoutSection

        if isEmpty {
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(96)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
            section = NSCollectionLayoutSection(group: group)
        } else {
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(116),
                heightDimension: .absolute(148)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(116),
                heightDimension: .absolute(148)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
            section.interGroupSpacing = 14
        }

        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16)
        section.boundarySupplementaryItems = [makeHeaderSupplementaryItem()]
        return section
    }

    private func makeHeroSectionLayout(showHeader: Bool, isEmpty: Bool) -> NSCollectionLayoutSection {
        let height: CGFloat = isEmpty ? 96 : 196
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(height)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 20
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16)
        if showHeader {
            section.boundarySupplementaryItems = [makeHeaderSupplementaryItem()]
        }
        return section
    }

    private func makeAddButtonLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(72)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 16, bottom: 24, trailing: 16)
        return section
    }

    private func makeCompletedSectionLayout(isEmpty: Bool) -> NSCollectionLayoutSection {
        let height: CGFloat = isEmpty ? 76 : 100
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(height)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 14
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 24, trailing: 16)
        section.boundarySupplementaryItems = [makeHeaderSupplementaryItem()]
        return section
    }

    private func makeHeaderSupplementaryItem() -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(34)
        )
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }

    private func handlePrimaryAction(for goal: Goal) {
        if goal.isReadyToPurchase {
            markGoalPurchased(goal)
        } else {
            presentAddMoney(for: goal)
        }
    }

    private func presentAddMoney(for goal: Goal) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let nav = storyboard.instantiateViewController(
            withIdentifier: "AddMoneyNav"
        ) as! UINavigationController
        guard let vc = nav.viewControllers.first as? AddMoneyAlertViewController else { return }
        
        vc.goal = goal
        vc.budgetRemaining = max(DatabaseManager.shared.fetchCurrentBudget()?.remainingBudget ?? 0, 0)
        vc.delegate = self

        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [
                .custom { context in
                    context.maximumDetentValue * 0.5
                }
            ]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }

        present(nav, animated: true)
    }

    private func presentAddGoalFlow() {
        guard
            let nav = storyboard?.instantiateViewController(withIdentifier: "AddGoalsNav") as? UINavigationController,
            let vc = nav.viewControllers.first as? AddGoalsViewController
        else { return }

        vc.onGoalSaved = { [weak self] in
            self?.reloadGoals()
        }

        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func presentEditGoal(for goal: Goal) {
        guard
            let nav = storyboard?.instantiateViewController(withIdentifier: "EditGoalsNav") as? UINavigationController,
            let vc = nav.viewControllers.first as? EditGoalsViewController
        else { return }

        vc.goal = goal
        vc.onGoalUpdated = { [weak self] in
            self?.reloadGoals()
        }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func presentGoalActions(for goal: Goal) {
        let alert = UIAlertController(title: goal.name, message: nil, preferredStyle: .actionSheet)

        let holdAction = UIAlertAction(title: "Hold Goal", style: .default) { [weak self] _ in
            self?.holdGoal(goal)
        }
        holdAction.isEnabled = goal.isActiveGoal && !goal.isCompleted && !goal.isOnHold
        alert.addAction(holdAction)

        alert.addAction(UIAlertAction(title: "Edit Goal", style: .default) { [weak self] _ in
            self?.presentEditGoal(for: goal)
        })

        alert.addAction(UIAlertAction(title: "Delete Goal", style: .destructive) { [weak self] _ in
            self?.confirmDelete(goal)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func holdGoal(_ goal: Goal) {
        guard goal.isActiveGoal, !goal.isCompleted, !goal.isOnHold else { return }
        guard DatabaseManager.shared.setGoalHoldState(id: goal.id, isOnHold: true) else { return }
        postGoalDataChange()
    }

    private func resumeGoal(_ goal: Goal) {
        guard DatabaseManager.shared.setGoalHoldState(id: goal.id, isOnHold: false) else { return }
        postGoalDataChange()
    }

    private func markGoalPurchased(_ goal: Goal) {
        guard DatabaseManager.shared.markGoalPurchased(id: goal.id) else { return }
        postGoalDataChange()
    }

    private func confirmDelete(_ goal: Goal) {
        let alert = UIAlertController(
            title: "Delete Goal",
            message: "This goal and its saved photo will be removed.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            DatabaseManager.shared.deleteGoal(id: goal.id)
            GoalImageStore.removeImage(for: goal.id)
            self?.postGoalDataChange()
        })
        present(alert, animated: true)
    }

    private func postGoalDataChange() {
        reloadGoals()
        NotificationCenter.default.post(name: .goalDataDidChange, object: nil)
        NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
    }

    @objc private func handleGoalDataChange() {
        reloadGoals()
    }

    @objc private func handleTouchFeedbackPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: goalsCollectionView)

        switch gesture.state {
        case .began, .changed:
            let nextIndexPath: IndexPath?

            if let indexPath = goalsCollectionView.indexPathForItem(at: location),
               shouldApplyTouchFeedback(at: indexPath) {
                nextIndexPath = indexPath
            } else {
                nextIndexPath = nil
            }

            updateTouchFeedback(to: nextIndexPath)

        case .ended, .cancelled, .failed:
            updateTouchFeedback(to: nil)

        default:
            break
        }
    }

    private func shouldApplyTouchFeedback(at indexPath: IndexPath) -> Bool {
        guard let section = GoalsSection(rawValue: indexPath.section) else { return false }

        switch section {
        case .badges:
            return badgeGoals.indices.contains(indexPath.item)
        case .active:
            return activeGoals.indices.contains(indexPath.item)
        case .completed:
            return completedGoals.indices.contains(indexPath.item)
        case .inactive:
            return inactiveGoals.indices.contains(indexPath.item)
        case .addGoal:
            return false
        }
    }

    private func updateTouchFeedback(to indexPath: IndexPath?) {
        guard touchFeedbackIndexPath != indexPath else { return }

        if let previousIndexPath = touchFeedbackIndexPath,
           let previousCell = goalsCollectionView.cellForItem(at: previousIndexPath) {
            setTouchFeedback(false, for: previousCell)
        }

        touchFeedbackIndexPath = indexPath

        if let indexPath,
           let currentCell = goalsCollectionView.cellForItem(at: indexPath) {
            setTouchFeedback(true, for: currentCell)
        }
    }

    private func setTouchFeedback(_ pressed: Bool, for cell: UICollectionViewCell) {
        switch cell {
        case let cell as GoalBadgeCollectionViewCell:
            cell.setTouchPressed(pressed)
        case let cell as OngoingGoalCollectionViewCell:
            cell.setTouchPressed(pressed)
        case let cell as ReachedGoalsCollectionViewCell:
            cell.setTouchPressed(pressed)
        default:
            break
        }
    }
    
    @objc private func showProfile() {
            guard let profile = storyboard?.instantiateViewController(withIdentifier: "ProfileViewController") else { return }
            navigationController?.pushViewController(profile, animated: true)
        }


    private func showGoalsOnboarding() {
        startOnboarding()
    }

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
        guard onboardingSteps.indices.contains(currentOnboardingStep) else { return }
        let step = onboardingSteps[currentOnboardingStep]
        spotlightView?.spotlight(
            on: step.view,
            title: step.title,
            message: step.message,
            stepIndex: currentOnboardingStep,
            tooltipBelow: step.tooltipBelow,
            animated: animated
        )
    }

    private func finishOnboarding() {
        UIView.animate(withDuration: 0.3, animations: {
            self.spotlightView?.alpha = 0
        }, completion: { _ in
            self.spotlightView?.removeFromSuperview()
            self.spotlightView = nil
        })
    }
}

extension GoalsViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        GoalsSection.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let section = GoalsSection(rawValue: section) else { return 0 }

        switch section {
        case .addGoal:
            return 1
        case .badges, .active, .completed, .inactive:
            return max(sectionGoals(for: section).count, 1)
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let section = GoalsSection(rawValue: indexPath.section) else {
            return UICollectionViewCell()
        }

        switch section {
        case .badges:
            guard !badgeGoals.isEmpty else {
                return placeholderCell(in: collectionView, section: .badges, for: indexPath)
            }

            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "GoalBadgeCollectionViewCell",
                for: indexPath
            ) as! GoalBadgeCollectionViewCell
            cell.configure(with: badgeGoals[indexPath.item])
            return cell

        case .active:
            guard !activeGoals.isEmpty else {
                return placeholderCell(in: collectionView, section: .active, for: indexPath)
            }

            let goal = activeGoals[indexPath.item]
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "OngoingGoalCollectionViewCell",
                for: indexPath
            ) as! OngoingGoalCollectionViewCell
            let mode: OngoingGoalCollectionViewCell.Mode = goal.isReadyToPurchase ? .readyToPurchase : .active
            cell.configure(with: goal, mode: mode)
            cell.onPrimaryAction = { [weak self] in
                self?.handlePrimaryAction(for: goal)
            }
            return cell

        case .addGoal:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "GoalAddButtonCollectionViewCell",
                for: indexPath
            ) as! GoalAddButtonCollectionViewCell
            cell.onTap = { [weak self] in
                self?.presentAddGoalFlow()
            }
            return cell

        case .completed:
            guard !completedGoals.isEmpty else {
                return placeholderCell(in: collectionView, section: .completed, for: indexPath)
            }

            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "ReachedGoalsCollectionViewCell",
                for: indexPath
            ) as! ReachedGoalsCollectionViewCell
            cell.configure(with: completedGoals[indexPath.item])
            return cell

        case .inactive:
            guard !inactiveGoals.isEmpty else {
                return placeholderCell(in: collectionView, section: .inactive, for: indexPath)
            }

            let goal = inactiveGoals[indexPath.item]
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "OngoingGoalCollectionViewCell",
                for: indexPath
            ) as! OngoingGoalCollectionViewCell
            cell.configure(with: goal, mode: .inactive)
            cell.onPrimaryAction = { [weak self] in
                self?.resumeGoal(goal)
            }
            return cell
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard
            kind == UICollectionView.elementKindSectionHeader,
            let section = GoalsSection(rawValue: indexPath.section),
            section != .addGoal
        else {
            return UICollectionReusableView()
        }

        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: GoalsSectionHeaderReusableView.reuseIdentifier,
            for: indexPath
        ) as! GoalsSectionHeaderReusableView
        header.configure(title: section.title, countText: countText(for: section))
        return header
    }

    private func placeholderCell(
        in collectionView: UICollectionView,
        section: GoalsSection,
        for indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PlaceHolderCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! PlaceHolderCollectionViewCell
        cell.configure(message: placeholderMessage(for: section), sizeStyle: placeholderStyle(for: section))
        return cell
    }

}

extension GoalsViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        guard let section = GoalsSection(rawValue: indexPath.section) else { return false }
        return section == .addGoal
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let section = GoalsSection(rawValue: indexPath.section) else { return false }
        return section == .addGoal
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let section = GoalsSection(rawValue: indexPath.section) else { return }

        switch section {
        case .addGoal:
            collectionView.deselectItem(at: indexPath, animated: false)
            presentAddGoalFlow()
        case .badges, .active, .completed, .inactive:
            return
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let section = GoalsSection(rawValue: indexPath.section)
        else { return nil }

        guard section == .active || section == .inactive else { return nil }

        let goals = sectionGoals(for: section)
        guard goals.indices.contains(indexPath.item) else { return nil }

        let goal = goals[indexPath.item]
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }

            let primaryAction: UIAction
            switch section {
            case .active:
                primaryAction = UIAction(title: "Hold Goal", image: UIImage(systemName: "pause.circle")) { _ in
                    self.holdGoal(goal)
                }
            case .inactive:
                primaryAction = UIAction(title: "Resume Goal", image: UIImage(systemName: "play.circle")) { _ in
                    self.resumeGoal(goal)
                }
            case .badges, .addGoal, .completed:
                return nil
            }

            let edit = UIAction(title: "Edit Goal", image: UIImage(systemName: "pencil")) { _ in
                self.presentEditGoal(for: goal)
            }

            let delete = UIAction(title: "Delete Goal", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.confirmDelete(goal)
            }

            return UIMenu(title: goal.name, children: [primaryAction, edit, delete])
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        contextMenuPreview(for: collectionView, configuration: configuration)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        contextMenuPreview(for: collectionView, configuration: configuration)
    }

    private func contextMenuPreview(
        for collectionView: UICollectionView,
        configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? NSIndexPath,
              let cell = collectionView.cellForItem(at: indexPath as IndexPath)
        else { return nil }

        let previewSourceView: UIView
        switch cell {
        case let goalCell as OngoingGoalCollectionViewCell:
            previewSourceView = goalCell.contextMenuPreviewView
        case let goalCell as ReachedGoalsCollectionViewCell:
            previewSourceView = goalCell.contextMenuPreviewView
        case let goalCell as GoalBadgeCollectionViewCell:
            previewSourceView = goalCell.contextMenuPreviewView
        default:
            previewSourceView = cell.contentView
        }

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(
            roundedRect: previewSourceView.bounds,
            cornerRadius: previewSourceView.layer.cornerRadius
        )

        let targetCenter = previewSourceView.superview?.convert(
            CGPoint(x: previewSourceView.frame.midX, y: previewSourceView.frame.midY),
            to: collectionView
        ) ?? previewSourceView.center
        let target = UIPreviewTarget(container: collectionView, center: targetCenter)

        if let snapshotView = makeContextMenuSnapshot(from: previewSourceView) {
            return UITargetedPreview(view: snapshotView, parameters: parameters, target: target)
        }

        return UITargetedPreview(view: previewSourceView, parameters: parameters, target: target)
    }

    private func makeContextMenuSnapshot(from sourceView: UIView) -> UIView? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale

        let renderer = UIGraphicsImageRenderer(size: sourceView.bounds.size, format: format)
        let image = renderer.image { _ in
            sourceView.drawHierarchy(in: sourceView.bounds, afterScreenUpdates: false)
        }

        let imageView = UIImageView(image: image)
        imageView.frame = sourceView.bounds
        imageView.contentMode = .scaleToFill
        imageView.layer.cornerRadius = sourceView.layer.cornerRadius
        imageView.layer.masksToBounds = true
        imageView.backgroundColor = .clear
        return imageView
    }
}

extension GoalsViewController: AddMoneyAlertViewControllerDelegate {

    func didAddMoney(amount: Double, goalId: UUID) {
        guard amount > 0 else { return }
        let success = DatabaseManager.shared.addMoneyToGoal(goalId: goalId, amount: amount)
        if success {
            postGoalDataChange()
        }
    }
}

extension GoalsViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === touchFeedbackRecognizer else { return true }

        var currentView = touch.view
        while let view = currentView {
            if view is UIControl {
                return false
            }
            currentView = view.superview
        }

        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === touchFeedbackRecognizer
    }
}
