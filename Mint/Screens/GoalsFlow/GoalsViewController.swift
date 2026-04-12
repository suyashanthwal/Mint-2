//
//  GoalsViewController.swift
//  BudgetApp
//
//  Created by Suyash Anthwal on 02/04/26.
//

import UIKit

class GoalsViewController: UIViewController {

    private enum LayoutMetrics {
        static let activeGoalHeight: CGFloat = 320
        static let reachedGoalHeight: CGFloat = 72
        static let sectionSpacing: CGFloat = 16
    }

    // MARK: - Outlets

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var totalSavingsView: UIView!
    @IBOutlet weak var activeGoalsSectionView: UIView!
    @IBOutlet weak var reachedGoalsSectionView: UIView!
    @IBOutlet weak var TotalSavingLabel: UILabel!
    @IBOutlet weak var TotalSavingStatsLabel: UILabel!
    @IBOutlet weak var ActiveGoalsCollectionView: UICollectionView!
    @IBOutlet weak var ReachedGoalsCollectionView: UICollectionView!

    // MARK: - Data

    private var hasCheckedOnboarding = false
    private var ongoingGoals: [Goal] = []
    private var completedGoals: [Goal] = []

    // MARK: - Onboarding State

    private var spotlightView: OnboardingSpotlightView?
    private var currentOnboardingStep = 0
    private var onboardingSteps: [OnboardingStep] = []

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        reloadGoals()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        registerCells()
        setupDelegatesAndDataSources()
        setupLayouts()
        onboardingSteps = [
            OnboardingStep(
                view: totalSavingsView,
                title: "Total Savings",
                message: "See how much you have saved across all your goals.",
                tooltipBelow: true
            ),
            OnboardingStep(
                view: activeGoalsSectionView,
                title: "Active Goals",
                message: "Track the goals you are still working toward and add money as you go.",
                tooltipBelow: false
            ),
            OnboardingStep(
                view: reachedGoalsSectionView,
                title: "Reached Goals",
                message: "Completed goals stay here so you can look back at what you have achieved.",
                tooltipBelow: false
            ),
        ]
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGoalDataChange),
            name: .goalDataDidChange,
            object: nil
        )
        reloadGoals()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCollectionLayouts()
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
    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = AppColors.background

        TotalSavingLabel.textColor  = AppColors.textPrimary

        TotalSavingStatsLabel.textColor = AppColors.textSecondary
        updateSummaryLabels()
    }

    // MARK: - Register Cells

    private func registerCells() {
        ActiveGoalsCollectionView.register(
            UINib(nibName: "OngoingGoalCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "OngoingGoalCollectionViewCell"
        )
        ReachedGoalsCollectionView.register(
            UINib(nibName: "ReachedGoalsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "ReachedGoalsCollectionViewCell"
        )
    }

    // MARK: - Delegates & Data Sources

    private func setupDelegatesAndDataSources() {
        ActiveGoalsCollectionView.delegate   = self
        ActiveGoalsCollectionView.dataSource = self
        ActiveGoalsCollectionView.isScrollEnabled = false
        ActiveGoalsCollectionView.showsVerticalScrollIndicator = false

        ReachedGoalsCollectionView.delegate   = self
        ReachedGoalsCollectionView.dataSource = self
        ReachedGoalsCollectionView.isScrollEnabled = false
        ReachedGoalsCollectionView.showsVerticalScrollIndicator = false
    }

    // MARK: - Layouts

    private func setupLayouts() {
        updateCollectionLayouts()
    }

    private func updateCollectionLayouts() {
        ActiveGoalsCollectionView.collectionViewLayout = makeOngoingLayout(
            width: ActiveGoalsCollectionView.bounds.width
        )
        ReachedGoalsCollectionView.collectionViewLayout = makeReachedLayout(
            width: ReachedGoalsCollectionView.bounds.width
        )
    }

    /// Vertical list — one full-width card per ongoing goal
    private func makeOngoingLayout(width: CGFloat) -> UICollectionViewFlowLayout {
        let layout                   = UICollectionViewFlowLayout()
        layout.itemSize              = CGSize(width: max(width, 0), height: LayoutMetrics.activeGoalHeight)
        layout.minimumLineSpacing    = LayoutMetrics.sectionSpacing
        layout.scrollDirection       = .vertical
        return layout
    }

    /// Vertical list — one full-width row per completed goal
    private func makeReachedLayout(width: CGFloat) -> UICollectionViewFlowLayout {
        let layout                   = UICollectionViewFlowLayout()
        layout.itemSize              = CGSize(width: max(width, 0), height: LayoutMetrics.reachedGoalHeight)
        layout.minimumLineSpacing    = 1
        layout.scrollDirection       = .vertical
        return layout
    }

    // MARK: - Helpers

    private var totalSaved: Double {
        (ongoingGoals + completedGoals).reduce(0) { $0 + $1.currentlySaved }
    }

    private func reloadGoals() {
        
        let goals = DatabaseManager.shared.fetchGoals()
        ongoingGoals = goals.filter { !$0.isCompleted }
        completedGoals = goals.filter { $0.isCompleted }
        reattachSavedImages(to: &ongoingGoals)
        reattachSavedImages(to: &completedGoals)
        updateSummaryLabels()

        guard isViewLoaded else { return }
        //
        updateCollectionLayouts()
        //
        ActiveGoalsCollectionView.reloadData()
        //
        ReachedGoalsCollectionView.reloadData()
    }
    
  
    private func saveImageToDisk(_ image: UIImage, for goal: Goal) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let url = imageURL(for: goal)
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Failed to save goal image:", error)
            return nil
        }
    }

    // Same filename formula used everywhere — single source of truth
    private func imageURL(for goal: Goal) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("goal_\(goal.id.uuidString)_photo.jpg")
    }

    // Called after every fetch — re-links disk files back to model objects
    private func reattachSavedImages(to goals: inout [Goal]) {
        for i in goals.indices {
            let url = imageURL(for: goals[i])
            if FileManager.default.fileExists(atPath: url.path) {
                goals[i].pickedImageURL = url
            }
        }
    }
    private func updateSummaryLabels() {
        TotalSavingLabel?.text = formatCurrency(totalSaved)
        TotalSavingStatsLabel?.text = "\(ongoingGoals.count) active • \(completedGoals.count) reached"
    }

    @objc private func handleGoalDataChange() {
        reloadGoals()
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter          = NumberFormatter()
        formatter.numberStyle  = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }

    // MARK: - Onboarding

    private func showGoalsOnboarding() { startOnboarding() }

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

            let frameInScroll = step.view.convert(step.view.bounds, to: scrollView)
            let idealOffset = frameInScroll.midY - (screenHeight / 2)
            let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            var finalOffset = max(0, min(idealOffset, maxOffset))

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

    // MARK: - Actions

    @objc private func addGoalTapped() {
        // TODO: present Add Goal sheet
    }
}

// MARK: - UICollectionViewDataSource

extension GoalsViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView === ActiveGoalsCollectionView {
            return ongoingGoals.count
        } else {
            return completedGoals.count
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        if collectionView === ActiveGoalsCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "OngoingGoalCollectionViewCell",
                for: indexPath
            ) as! OngoingGoalCollectionViewCell

            cell.configure(with: ongoingGoals[indexPath.item])

            // Wire up buttons with closures / callbacks
            cell.onAddMoney = { [weak self] in
                guard let self else { return }
                self.handleAddMoney(for: self.ongoingGoals[indexPath.item])
            }
            cell.onDetail = { [weak self] in
                guard let self else { return }
                self.handleDetail(for: self.ongoingGoals[indexPath.item])
            }
            // Image picking callback
            // Called when user picks a photo from the library 
            // save it to disk so it survives reloads, then update
            // the in-memory model so configure() can find it immediately
            let goal = ongoingGoals[indexPath.item]
            cell.onImagePicked = { [weak self] image in
                guard let self else { return }
                if let url = self.saveImageToDisk(image, for: goal) {
                    self.ongoingGoals[indexPath.item].pickedImageURL = url
                }
            }
            
            return cell

        } else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "ReachedGoalsCollectionViewCell",
                for: indexPath
            ) as! ReachedGoalsCollectionViewCell

            cell.configure(with: completedGoals[indexPath.item])
            return cell
        }
    }
}

// MARK: - UICollectionViewDelegate

extension GoalsViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        if collectionView === ActiveGoalsCollectionView {
            handleDetail(for: ongoingGoals[indexPath.item])
        }
    }
}

// MARK: - Navigation Helpers

private extension GoalsViewController {

    func handleAddMoney(for goal: Goal) {

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(
            withIdentifier: "AddMoneyAlertViewController"
        ) as! AddMoneyAlertViewController

        vc.goal = goal
        vc.budgetRemaining = max(DatabaseManager.shared.fetchCurrentBudget()?.remainingBudget ?? 0, 0)
        vc.delegate = self

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [
                .custom { context in
                    return context.maximumDetentValue * 0.5   // 50% height
                }
            ]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }

        present(vc, animated: true)
    }
    
    func handleDetail(for goal: Goal) {
        guard
            let nav = storyboard?.instantiateViewController(withIdentifier: "EditGoalsNav") as? UINavigationController,
            let vc  = nav.viewControllers.first as? EditGoalsViewController
        else { return }

        vc.goal = goal
        vc.onGoalUpdated = { [weak self] in
            self?.reloadGoals()
        }
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }
}

extension GoalsViewController: AddMoneyAlertViewControllerDelegate {

    func didAddMoney(amount: Double, goalId: UUID) {
        guard amount > 0 else { return }
        let success = DatabaseManager.shared.addMoneyToGoal(goalId: goalId, amount: amount)
        if success {
            reloadGoals()
            NotificationCenter.default.post(name: .goalDataDidChange, object: nil)
            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
        }
    }
}
