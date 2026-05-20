
import UIKit

class SelectSubsViewController: UIViewController {

    private struct PaymentTemplate {
        let name: String
        let amount: Double
        let icon: String
        let categoryName: String?
        let duration: PaymentDuration
        let note: String?
    }

    @IBOutlet var categoryIcons: [UIImageView]!
    @IBOutlet var categoryViews: [UIView]!
    @IBOutlet var categoryLabels: [UILabel]!

    @IBOutlet weak var skip: UIButton!
    private var selectedViews: Set<Int> = []
    private let paymentTemplates: [PaymentTemplate] = [
        .init(name: "Mobile Recharge", amount: 899, icon: "phone.bubble.fill",
              categoryName: "Transport", duration: .monthly, note: nil),
        .init(name: "Netflix", amount: 699, icon: "movieclapper.fill",
              categoryName: "Entertainment", duration: .monthly, note: nil),
        .init(name: "Apple Music", amount: 89, icon: "music.note",
              categoryName: "Entertainment", duration: .monthly, note: nil),
        .init(name: "Spotify", amount: 119, icon: "music.note",
              categoryName: "Entertainment", duration: .monthly, note: nil),
        .init(name: "YouTube Premium", amount: 149, icon: "arrowtriangle.forward.fill",
              categoryName: "Entertainment", duration: .monthly, note: nil),
        .init(name: "Wifi", amount: 799, icon: "wifi.circle.fill",
              categoryName: "Others", duration: .monthly, note: nil),
        .init(name: "Gym Membership", amount: 1200, icon: "dumbbell.fill",
              categoryName: "Health & Fitness", duration: .monthly, note: nil),
        .init(name: "Cloud", amount: 75, icon: "cloud.fill",
              categoryName: "Others", duration: .monthly, note: nil),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        setupViews()
    }

    @IBAction func countinueButtonTapped(_ sender: UIButton) {
        finishOnboarding(applySelections: true)
    }
    @IBAction func skipButtonTapped(_ sender: Any) {
        finishOnboarding(applySelections: false)
    }

    private func finishOnboarding(applySelections: Bool) {
        let db = DatabaseManager.shared

        if applySelections {
            let existingPaymentNames = Set(
                db.fetchRecurringPayments().map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            )

            for index in selectedViews.sorted() where index < paymentTemplates.count {
                let template = paymentTemplates[index]
                let normalizedName = template.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !existingPaymentNames.contains(normalizedName) else { continue }

                let categoryId = template.categoryName.flatMap { db.fetchCategory(named: $0)?.id }
                db.insertRecurringPayment(
                    name: template.name,
                    categoryId: categoryId,
                    duration: template.duration,
                    amount: template.amount,
                    nextDate: defaultNextDate(),
                    icon: template.icon,
                    isAlertEnabled: true,
                    isAddAutomatically: true,
                    note: template.note
                )
            }
        }

        if let currentUserId = db.currentUserId {
            db.markSetupComplete(for: currentUserId, isComplete: true)
        }

        BillSubscriptionReminderManager.shared.refreshAllReminders()

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "TabBar")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            
            window.rootViewController = vc
            window.makeKeyAndVisible()
            
            UIView.transition(with: window,
                              duration: 0.3,
                              options: .transitionCrossDissolve,
                              animations: nil)
        }
    }

    private func defaultNextDate() -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    }
    private func setupViews() {
        for (index, view) in categoryViews.enumerated() {
            view.tag = index
            view.layer.cornerRadius = 18
            view.layer.borderWidth = 1
            view.layer.borderColor = AppColors.cardBorder.cgColor
            view.clipsToBounds = true
            view.backgroundColor = AppColors.sectionBackground
            categoryLabels[index].textColor = AppColors.textSecondary
            categoryLabels[index].font = MintFont.space(size: 15, weight: .semibold)
            categoryLabels[index].removeCharacterSpacing()
            categoryIcons[index].tintColor = AppColors.textSecondary
            let tap = UITapGestureRecognizer(target: self, action: #selector(categoryTapped(_:)))
            view.addGestureRecognizer(tap)
        }
    }

    @objc private func categoryTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        let tag = view.tag
        let isSelected = selectedViews.contains(tag)

        if isSelected {
            selectedViews.remove(tag)
        } else {
            selectedViews.insert(tag)
        }

        UIView.animate(withDuration: 0.2) {
            view.backgroundColor = self.selectedViews.contains(tag)
                ? AppColors.brand
                : AppColors.sectionBackground
            view.layer.borderColor = self.selectedViews.contains(tag)
                ? AppColors.brand.cgColor
                : AppColors.cardBorder.cgColor
            self.categoryLabels[tag].textColor = self.selectedViews.contains(tag)
                ? AppColors.brandText
                : AppColors.textSecondary
            self.categoryIcons[tag].tintColor = self.selectedViews.contains(tag) ? AppColors.brandText : AppColors.textSecondary
        }
    }

    private func configureAppearance() {
        view.backgroundColor = AppColors.background
        navigationController?.navigationBar.tintColor = AppColors.textPrimary
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: AppColors.textPrimary,
            .font: MintFont.space(size: 17, weight: .semibold)
        ]

        if let titleLabel = labels(matching: "Any Subscriptions or Regular payments").first {
            titleLabel.font = MintFont.syne(size: 29, weight: .bold)
            titleLabel.textColor = AppColors.textPrimary
            titleLabel.removeCharacterSpacing()
        }

        if let subtitleLabel = labels(matching: "Select the ones relevant to you").first {
            subtitleLabel.font = MintFont.space(size: 16, weight: .medium)
            subtitleLabel.textColor = AppColors.textSecondary
            subtitleLabel.removeCharacterSpacing()
        }

        buttons(titled: "Continue").first?.applyPrimaryOnboardingStyle()
        skip.applySecondaryOnboardingStyle()
    }

    private func labels(matching text: String) -> [UILabel] {
        view.allSubviews.compactMap { $0 as? UILabel }.filter { $0.text == text }
    }

    private func buttons(titled title: String) -> [UIButton] {
        view.allSubviews.compactMap { $0 as? UIButton }.filter { $0.currentTitle == title }
    }
}
