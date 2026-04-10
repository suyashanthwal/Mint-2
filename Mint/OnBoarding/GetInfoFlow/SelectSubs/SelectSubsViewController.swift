//
//  SelectSubsViewController.swift
//  Mint
//
//  Created by AnushkB on 01/04/26.
//

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
    @IBOutlet var categoryLabels: [UILabel]! // connect labels separately

    @IBOutlet weak var skip: UIButton!
    private var selectedViews: Set<Int> = []
    private let paymentTemplates: [PaymentTemplate] = [
        .init(name: "Mobile Recharge", amount: 899, icon: "phone.bubble.fill",
              categoryName: "Transport", duration: .monthly, note: "Starter setup"),
        .init(name: "Netflix", amount: 699, icon: "movieclapper.fill",
              categoryName: "Entertainment", duration: .monthly, note: "Starter setup"),
        .init(name: "Apple Music", amount: 89, icon: "music.note",
              categoryName: "Entertainment", duration: .monthly, note: "Starter setup"),
        .init(name: "Spotify", amount: 119, icon: "music.note",
              categoryName: "Entertainment", duration: .monthly, note: "Starter setup"),
        .init(name: "YouTube Premium", amount: 149, icon: "arrowtriangle.forward.fill",
              categoryName: "Entertainment", duration: .monthly, note: "Starter setup"),
        .init(name: "Wifi", amount: 799, icon: "wifi.circle.fill",
              categoryName: "Others", duration: .monthly, note: "Starter setup"),
        .init(name: "Gym Membership", amount: 1200, icon: "dumbbell.fill",
              categoryName: "Health & Fitness", duration: .monthly, note: "Starter setup"),
        .init(name: "Cloud", amount: 75, icon: "cloud.fill",
              categoryName: "Others", duration: .monthly, note: "Starter setup"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
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
        db.deleteAllRecurringPaymentsForCurrentUser()
        db.deleteAllBillsForCurrentUser()

        if applySelections {
            for index in selectedViews.sorted() where index < paymentTemplates.count {
                let template = paymentTemplates[index]
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
            view.layer.cornerRadius = 12
            view.clipsToBounds = true
            view.backgroundColor = AppColors.sectionBackground
            categoryLabels[index].textColor = AppColors.textSecondary
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
            self.categoryLabels[tag].textColor = self.selectedViews.contains(tag)
                ? AppColors.brandText
                : AppColors.textSecondary
            self.categoryIcons[tag].tintColor = self.selectedViews.contains(tag) ? AppColors.brandText : AppColors.textSecondary
        }
    }

}
