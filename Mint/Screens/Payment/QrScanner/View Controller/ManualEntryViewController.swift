
import UIKit

 class ManualEntryViewController: UIViewController, UITextFieldDelegate {

    private enum Constants {
        static let fallbackExpenseCategoryName = "Others"
        static let fallbackExpenseCategoryColor = "#7D8597"
        static let fallbackExpenseCategoryIcon = "cube.box.fill"
    }

    @IBOutlet weak var amountValueTextField: UITextField!
    @IBOutlet weak var categoryValueLabel: UILabel!
    @IBOutlet weak var categoryIconImageView: UIImageView!
    @IBOutlet weak var fromTitleLabel: UILabel!
    @IBOutlet weak var fromValueLabel: UILabel!
    @IBOutlet weak var noteValueLabel: UILabel!
    @IBOutlet weak var dateValueLabel: UILabel!
     @IBOutlet weak var currencySymbolLabel : UILabel!
    @IBOutlet weak var categoryRowView: UIView!
    @IBOutlet weak var fromRowView: UIView!
    @IBOutlet weak var noteRowView: UIView!
    @IBOutlet weak var dateRowView: UIView!

    @IBOutlet weak var nextDateButton: UIButton!

    @IBOutlet weak var expenseIncomeSegment: UISegmentedControl!

    @IBOutlet weak var rowsStackView: UIStackView!

    @IBOutlet  var iconCircles : [UIView]!

    var availableCategories: [Category] = []
    private let db = DatabaseManager.shared

    private var amount: Double = 0
    private var selectedCategory: Category?
    private var selectedDate: Date = Date()
    private var isExpense = true
    private var noteText = ""
    private var selectedExpenseSource = "Savings"
    private var selectedIncomeSource  = "Salary"

    private let expenseSources = ["Cash", "UPI", "Card", "Net Banking", "Savings"]
    private let incomeSources  = ["Salary", "Freelance", "Business", "Gift", "Other"]

    override func viewDidLoad() {
        super.viewDidLoad()
        loadCategoriesFromDatabase()
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        view.backgroundColor = AppColors.background
        view.overrideUserInterfaceStyle = .dark
        styleComponents()
        configureAmountTextField()
        wireUpGestures()
        updateScreen()
    }
     
    private func wireUpGestures() {
        let rows: [(UIView, Selector)] = [
            (categoryRowView, #selector(categoryTapped)),
            (fromRowView,     #selector(fromTapped)),
            (noteRowView,     #selector(noteTapped)),
            (dateRowView,     #selector(dateTapped))
        ]
        for (row, action) in rows {
            row.isUserInteractionEnabled = true
            row.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                             action: action))
        }
    }

    private func configureAmountTextField() {
        amountValueTextField.delegate = self
        amountValueTextField.keyboardType = .decimalPad
        amountValueTextField.textColor = AppColors.textPrimary
        amountValueTextField.tintColor = AppColors.brand
        amountValueTextField.backgroundColor = .clear
        amountValueTextField.attributedPlaceholder = NSAttributedString(
            string: amountValueTextField.placeholder ?? "",
            attributes: [.foregroundColor: AppColors.textSecondary]
        )
        amountValueTextField.addTarget(self, action: #selector(amountFieldChanged(_:)), for: .editingChanged)
    }

    private func updateScreen() {
        
        amountValueTextField.text = amount == 0 ? "" : formattedAmountText(amount)

        categoryRowView.isHidden = !isExpense

        fromTitleLabel.text = isExpense ? "FROM" : "TO"
        fromValueLabel.text = isExpense ? selectedExpenseSource : selectedIncomeSource

        if let cat = selectedCategory {
            categoryValueLabel.text     = cat.name
            categoryIconImageView.image = UIImage(systemName: cat.icon)
            
        } else {
            categoryValueLabel.text     = Constants.fallbackExpenseCategoryName
            categoryIconImageView.image = UIImage(systemName: Constants.fallbackExpenseCategoryIcon)
        }
        categoryIconImageView.tintColor = AppColors.brand
      
        noteValueLabel.textColor = noteText.isEmpty
            ? AppColors.textSecondary
            : AppColors.textPrimary

        dateValueLabel.text = readableDate(selectedDate)
        
        let tomorrow = Calendar.current.date(byAdding: .day,
                                              value: 1,
                                              to: selectedDate) ?? selectedDate
        nextDateButton.isEnabled = tomorrow <= Date()
        nextDateButton.alpha     = nextDateButton.isEnabled ? 1.0 : 0.35

        UIView.animate(withDuration: 0.2) {
            self.rowsStackView.layoutIfNeeded()
        }
    }

    private func readableDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    @IBAction func closeTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction func saveTapped(_ sender: UIButton) {
        guard amount > 0 else {
            amountValueTextField.becomeFirstResponder()
            return
        }
        buildAndSave()
    }

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        isExpense = sender.selectedSegmentIndex == 0
        syncDefaultCategoryForCurrentMode()
        updateScreen()
    }

    @IBAction func prevDateTapped(_ sender: UIButton) {
        selectedDate = Calendar.current.date(byAdding: .day,
                                              value: -1,
                                              to: selectedDate) ?? selectedDate
        updateScreen()
    }

    @IBAction func nextDateTapped(_ sender: UIButton) {
        let next = Calendar.current.date(byAdding: .day,
                                          value: 1,
                                          to: selectedDate) ?? selectedDate
        guard next <= Date() else { return }
        selectedDate = next
        updateScreen()
    }

     @objc private func noteTapped()   { showNoteAlert() }
     @objc private func dateTapped()   { showDatePicker() }
     @objc private func amountFieldChanged(_ textField: UITextField) {
         amount = parsedAmount(from: textField.text)
     }

     @objc private func categoryTapped() {
         let options = availableCategories
             .filter { $0.type == (isExpense ? .expense : .income) }
             .map { $0.name }

         let list = options.isEmpty
             ? [Constants.fallbackExpenseCategoryName]
             : options

         showPicker(title: "Category",
                    options: list,
                    current: selectedCategory?.name ?? Constants.fallbackExpenseCategoryName) { [weak self] picked in
             guard let self else { return }
             self.selectedCategory = self.availableCategories.first { $0.name == picked }
             self.updateScreen()
         }
     }

     @objc private func fromTapped() {
         if isExpense {
             showPicker(title: "Pay from",
                        options: expenseSources,
                        current: selectedExpenseSource) { [weak self] picked in
                 self?.selectedExpenseSource = picked
                 self?.updateScreen()
             }
         } else {
             showPicker(title: "Income source",
                        options: incomeSources,
                        current: selectedIncomeSource) { [weak self] picked in
                 self?.selectedIncomeSource = picked
                 self?.updateScreen()
             }
         }
     }

     private func showPicker(title: String,
                              options: [String],
                              current: String,
                              onPick: @escaping (String) -> Void) {
         let sheet = UIAlertController(title: title,
                                        message: nil,
                                        preferredStyle: .actionSheet)
         sheet.overrideUserInterfaceStyle = .dark
         for option in options {
             let action = UIAlertAction(title: option, style: .default) { _ in
                 onPick(option)
             }
             action.setValue(option == current, forKey: "checked")
             sheet.addAction(action)
         }
         sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
         present(sheet, animated: true)
     }

     private func showNoteAlert() {
         let alert = UIAlertController(title: "Add a note",
                                        message: nil,
                                        preferredStyle: .alert)
         alert.overrideUserInterfaceStyle = .dark
         alert.addTextField {
             $0.placeholder = "What was this for?"
             $0.text        = self.noteText
             $0.textColor = AppColors.textPrimary
             $0.tintColor = AppColors.brand
             $0.backgroundColor = AppColors.inputBackground
         }
         alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
         alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
             self?.noteText = alert.textFields?.first?.text ?? ""
             self?.updateScreen()
         })
         present(alert, animated: true)
     }

     private func showDatePicker() {
         let alert = UIAlertController(title: "Pick a date",
                                        message: "\n\n\n\n\n\n\n\n\n",
                                        preferredStyle: .actionSheet)
         alert.overrideUserInterfaceStyle = .dark
         let picker = UIDatePicker()
         picker.datePickerMode           = .date
         picker.preferredDatePickerStyle = .wheels
         picker.maximumDate              = Date()
         picker.date                     = selectedDate
         picker.applyMintDatePickerStyle()
         picker.translatesAutoresizingMaskIntoConstraints = false
         alert.view.addSubview(picker)

         NSLayoutConstraint.activate([
             picker.topAnchor.constraint(
                 equalTo: alert.view.topAnchor, constant: 50),
             picker.leadingAnchor.constraint(
                 equalTo: alert.view.leadingAnchor),
             picker.trailingAnchor.constraint(
                 equalTo: alert.view.trailingAnchor)
         ])

         alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
             self?.selectedDate = picker.date
             self?.updateScreen()
         })
         alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
         present(alert, animated: true)
     }
     
     private func styleComponents() {

         currencySymbolLabel.textColor = AppColors.brand
         amountValueTextField.textAlignment = .left
         iconCircles?.prefix(2).forEach { circle in
                 circle.backgroundColor = AppColors.brandLight
                 circle.layer.borderWidth = 1
                 circle.layer.borderColor = AppColors.brand.withAlphaComponent(0.35).cgColor
                
             }
         
         iconCircles?.suffix(from: 2).forEach { circle in
                 circle.backgroundColor = AppColors.inputBackground
                 circle.layer.borderWidth = 1
                 circle.layer.borderColor = AppColors.cardBorder.cgColor
                 
             }

         [categoryRowView, fromRowView, noteRowView, dateRowView].forEach {
             $0?.backgroundColor = AppColors.inputBackground
             $0?.layer.cornerRadius = 14
             $0?.layer.borderWidth = 1
             $0?.layer.borderColor = AppColors.cardBorder.withAlphaComponent(0.7).cgColor
         }

         [categoryValueLabel, fromTitleLabel, fromValueLabel, noteValueLabel, dateValueLabel].forEach {
             $0?.textColor = AppColors.textPrimary
         }
         fromTitleLabel.textColor = AppColors.textSecondary
         categoryIconImageView.tintColor = AppColors.brand

         expenseIncomeSegment.backgroundColor          = AppColors.sectionBackground
         expenseIncomeSegment.selectedSegmentTintColor = AppColors.inputBackground
         expenseIncomeSegment.layer.borderWidth = 1
         expenseIncomeSegment.layer.borderColor = AppColors.cardBorder.cgColor
         expenseIncomeSegment.setTitleTextAttributes(
             [.foregroundColor: AppColors.textSecondary,
              .font: MintFont.space(size: 14, weight: .medium)],
             for: .normal
         )
         expenseIncomeSegment.setTitleTextAttributes(
             [.foregroundColor: AppColors.textPrimary,
              .font: MintFont.space(size: 14, weight: .semibold)],
             for: .selected
         )

         nextDateButton.tintColor = AppColors.brand
         view.applyMintTypography()
     }

     private func formattedAmountText(_ amount: Double) -> String {
         if amount.rounded() == amount {
             return String(Int(amount))
         }
         return String(format: "%.2f", amount)
     }

     private func parsedAmount(from text: String?) -> Double {
         let sanitized = (text ?? "")
             .replacingOccurrences(of: "₹", with: "")
             .replacingOccurrences(of: ",", with: "")
             .trimmingCharacters(in: .whitespacesAndNewlines)

         return Double(sanitized) ?? 0
     }

     func textFieldDidBeginEditing(_ textField: UITextField) {
         if textField === amountValueTextField && amount == 0 {
             textField.text = nil
         }
     }

     func textFieldDidEndEditing(_ textField: UITextField) {
         if textField === amountValueTextField {
             amount = parsedAmount(from: textField.text)
             updateScreen()
         }
     }
    
     
     private func buildAndSave() {
         amount = parsedAmount(from: amountValueTextField.text)
         let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
         let note = trimmedNote.isEmpty ? nil : trimmedNote

         if isExpense {
             let source: TransactionSource
             switch selectedExpenseSource {
             case "UPI":  source = .upi
             case "Card": source = .ecommerce
             default:     source = .manual
             }

             guard let categoryId = resolvedExpenseCategoryId() else { return }
             _ = db.insertExpenseTransaction(
                 name: selectedCategory?.name ?? Constants.fallbackExpenseCategoryName,
                 amount: amount,
                 timestamp: selectedDate,
                 categoryId: categoryId,
                 status: true,
                 expenseType: selectedExpenseSource,
                 source: source,
                 note: note
             )
         } else {
             _ = db.insertIncomeTransaction(
                 name: selectedIncomeSource,
                 amount: amount,
                 timestamp: selectedDate,
                 sourceName: selectedIncomeSource,
                 source: .manual,
                 note: note
             )
         }

         db.resetMonthlyExpense()
         NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
         dismiss(animated: true)
     }

     private func loadCategoriesFromDatabase() {
         availableCategories = db.fetchCategories()

         if !availableCategories.contains(where: { $0.type == .expense }) {
             _ = db.ensureCategory(
                 name: Constants.fallbackExpenseCategoryName,
                 color: Constants.fallbackExpenseCategoryColor,
                 icon: Constants.fallbackExpenseCategoryIcon,
                 budget: 0,
                 type: .expense
             )
             availableCategories = db.fetchCategories()
         }

         if availableCategories.isEmpty {
             availableCategories = [
                 Category(
                     name: Constants.fallbackExpenseCategoryName,
                     color: Constants.fallbackExpenseCategoryColor,
                     icon: Constants.fallbackExpenseCategoryIcon,
                     budget: 0,
                     type: .expense
                 )
             ]
         }

         syncDefaultCategoryForCurrentMode()
     }

     private func resolvedExpenseCategoryId() -> UUID? {
         if let selectedCategory,
            let selectedCategoryId = db.fetchCategory(named: selectedCategory.name)?.id {
             return selectedCategoryId
         }

         return db.ensureCategory(
             name: Constants.fallbackExpenseCategoryName,
             color: Constants.fallbackExpenseCategoryColor,
             icon: Constants.fallbackExpenseCategoryIcon,
             budget: 0,
             type: .expense
         )
     }

     private func syncDefaultCategoryForCurrentMode() {
         guard isExpense else { return }

         let expenseCategories = availableCategories.filter { $0.type == .expense }

         if let currentCategory = selectedCategory,
            currentCategory.type == .expense,
            expenseCategories.contains(where: { $0.id == currentCategory.id }) {
             return
         }

         if let firstExpenseCategory = expenseCategories.first {
             selectedCategory = firstExpenseCategory
         } else if let ensuredCategoryId = db.ensureCategory(
             name: Constants.fallbackExpenseCategoryName,
             color: Constants.fallbackExpenseCategoryColor,
             icon: Constants.fallbackExpenseCategoryIcon,
             budget: 0,
             type: .expense
         ) {
             availableCategories = db.fetchCategories()
             selectedCategory = availableCategories.first(where: { $0.id == ensuredCategoryId })
         }
     }
}
