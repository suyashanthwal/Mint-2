
import UIKit

class EditTransactionViewController: UIViewController {

    @IBOutlet weak var CategoryButton: UIButton!
    @IBOutlet weak var CategoryMenu: UIMenu!
    @IBOutlet weak var TransactionAmount: UITextField!
    @IBOutlet weak var TransactionDateandTime: UIDatePicker!
    
    @IBOutlet var CardView: [UIView]!
    

    var transaction: Transaction?
    var onTransactionUpdated: (() -> Void)?

    private let db = DatabaseManager.shared
    private var availableCategories: [Category] = []
    private var selectedCategory: Category?

    override func viewDidLoad() {
        super.viewDidLoad()
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        setupUI()
        loadCategories()
        populateFields()
    }

    @IBAction func doneButton(_ sender: Any) {
        guard let transaction else { return }
        guard let amount = parsedAmount(from: TransactionAmount.text), amount > 0 else {
            showAlert(title: "Invalid Amount", message: "Please enter a valid amount before saving.")
            return
        }

        let didUpdate: Bool
        switch transaction.type {
        case .expense:
            guard let selectedCategory else {
                showAlert(title: "Select Category", message: "Please choose a category before saving.")
                return
            }

            didUpdate = db.updateTransaction(
                id: transaction.id,
                amount: amount,
                timestamp: TransactionDateandTime.date,
                categoryId: selectedCategory.id
            )
        case .income:
            let sourceName = selectedCategory?.name ?? transaction.sourceName ?? transaction.name
            didUpdate = db.updateTransaction(
                id: transaction.id,
                amount: amount,
                timestamp: TransactionDateandTime.date,
                sourceName: sourceName
            )
        }

        guard didUpdate else {
            showAlert(title: "Unable to Save", message: "The transaction could not be updated right now.")
            return
        }

        dismiss(animated: true) {
            self.onTransactionUpdated?()
            NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
        }
    }

    @IBAction func cancelButton(_ sender: Any) {
        dismiss(animated: true)
    }

    private func setupUI() {
        view.backgroundColor = AppColors.background
        TransactionAmount.keyboardType = .decimalPad
        TransactionAmount.backgroundColor = AppColors.card
        TransactionAmount.textColor = AppColors.textPrimary

        TransactionDateandTime.tintColor = AppColors.brand
        CategoryButton.showsMenuAsPrimaryAction = true
        CategoryButton.setTitleColor(AppColors.textPrimary, for: .normal)
        
        for v in CardView {
            v.backgroundColor = AppColors.card
        }
    }

    private func loadCategories() {
        let fetchedCategories = db.fetchCategories()
        guard let transaction else {
            availableCategories = fetchedCategories
            buildCategoryMenu()
            return
        }

        let matchingTypeCategories = fetchedCategories.filter { category in
            switch transaction.type {
            case .expense:
                return category.type == .expense
            case .income:
                return category.type == .income
            }
        }

        availableCategories = matchingTypeCategories.isEmpty ? fetchedCategories : matchingTypeCategories

        if let categoryId = transaction.categoryId {
            selectedCategory = availableCategories.first(where: { $0.id == categoryId })
                ?? fetchedCategories.first(where: { $0.id == categoryId })
        } else {
            let incomeLabel = transaction.sourceName ?? transaction.name
            selectedCategory = availableCategories.first {
                $0.name.caseInsensitiveCompare(incomeLabel) == .orderedSame
            }
        }

        buildCategoryMenu()
    }

    private func populateFields() {
        guard let transaction else { return }

        TransactionAmount.text = formattedAmount(transaction.amount)
        TransactionDateandTime.date = transaction.timestamp

        if let selectedCategory {
            CategoryButton.setTitle(selectedCategory.name, for: .normal)
        } else if transaction.type == .income {
            CategoryButton.setTitle(transaction.sourceName ?? transaction.name, for: .normal)
        } else {
            CategoryButton.setTitle("Select Category", for: .normal)
        }
    }

    private func buildCategoryMenu() {
        guard !availableCategories.isEmpty else {
            CategoryButton.menu = nil
            return
        }

        let actions = availableCategories.map { category in
            UIAction(
                title: category.name,
                state: category.id == selectedCategory?.id ? .on : .off
            ) { [weak self] _ in
                self?.selectedCategory = category
                self?.CategoryButton.setTitle(category.name, for: .normal)
                self?.buildCategoryMenu()
            }
        }

        let menuTitle = transaction?.type == .income ? "Source" : "Category"
        let menu = UIMenu(title: menuTitle, children: actions)
        CategoryMenu = menu
        CategoryButton.menu = menu
    }

    private func parsedAmount(from text: String?) -> Double? {
        guard let text else { return nil }
        let filtered = text.filter { $0.isNumber || $0 == "." }
        return Double(filtered)
    }

    private func formattedAmount(_ amount: Double) -> String {
        if amount == floor(amount) {
            return String(Int(amount))
        }

        let rawValue = String(format: "%.2f", amount)
        return rawValue.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
