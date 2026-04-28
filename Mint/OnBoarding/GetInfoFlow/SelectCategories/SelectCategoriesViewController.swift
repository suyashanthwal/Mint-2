import UIKit

class SelectCategoriesViewController: UIViewController {

    private struct CategoryTemplate {
        let name: String
        let color: String
        let icon: String
    }

    @IBOutlet var categoryIcons: [UIImageView]!
    @IBOutlet var categoryViews: [UIView]!
    @IBOutlet var categoryLabels: [UILabel]!

    @IBOutlet weak var skip: UIButton!
    private var selectedViews: Set<Int> = []
    private let categoryTemplates: [CategoryTemplate] = [
        .init(name: "Food", color: "#FF6B6B", icon: "fork.knife"),
        .init(name: "Shopping", color: "#4D96FF", icon: "bag.fill"),
        .init(name: "Transport", color: "#6BCB77", icon: "car"),
        .init(name: "Subscriptions", color: "#B983FF", icon: "calendar.badge.checkmark"),
        .init(name: "Entertainment", color: "#FF8C42", icon: "theatermasks.fill"),
        .init(name: "Travel", color: "#45B7D1", icon: "airplane.departure"),
        .init(name: "Health & Fitness", color: "#2EC4B6", icon: "dumbbell.fill"),
        .init(name: "Others", color: "#7D8597", icon: "cube.box.fill"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let shouldApplySelections: Bool
        if let button = sender as? UIButton {
            shouldApplySelections = button !== skip
        } else {
            shouldApplySelections = true
        }
        replaceSelectedCategories(shouldApplySelections: shouldApplySelections)
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

    private func replaceSelectedCategories(shouldApplySelections: Bool) {
        let db = DatabaseManager.shared
        db.deleteAllCategoriesForCurrentUser()

        guard shouldApplySelections, !selectedViews.isEmpty else { return }

        for index in selectedViews.sorted() where index < categoryTemplates.count {
            let template = categoryTemplates[index]
            if let categoryId = db.insertCategory(
                name: template.name,
                color: template.color,
                icon: template.icon,
                budget: 0
            ) {
                db.linkCategoryToCurrentBudget(categoryId: categoryId)
            }
        }
    }
}
