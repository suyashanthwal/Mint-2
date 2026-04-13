import UIKit

enum EntryMode {
    case subscription
    case bill
}

class AddSubsAndBillsViewController: UIViewController {

    var mode: EntryMode = .subscription
    var onEntrySaved: (() -> Void)?

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var intervalLabel: UILabel!

    @IBOutlet weak var selectedDateLabel: UILabel!
    @IBOutlet weak var intervalPicker: UIPickerView!
    @IBOutlet weak var intervalPickerHeight: NSLayoutConstraint!
    @IBOutlet weak var intervalRowStack: UIStackView!

    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var datePickerHeight: NSLayoutConstraint!
    @IBOutlet weak var dueDateRowStack: UIStackView!

    @IBOutlet weak var typeSegment: UISegmentedControl!

    @IBOutlet weak var autoAddToggle: UISwitch!
    @IBOutlet weak var alertToggle: UISwitch!
    @IBOutlet weak var intervalTitleLabel: UILabel!
    @IBOutlet weak var dueDateTitleLabel: UILabel!
    @IBOutlet weak var alertSectionView: UIView!
    @IBOutlet weak var autoAddSectionView: UIView!
    @IBOutlet weak var notesTextView: UITextField!

    @IBOutlet var AllBackgroundViews: [UIView]!
    @IBOutlet var AllCardViews: [UIView]!

    var intervals: [String] = []
    var pickerVisible = false
    var datePickerVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        setupUI()
        setupPickers()
        setupGestures()
        setupDatePicker()
        applyModeUI()
    }

    func setupUI() {
        for backgroundview in AllBackgroundViews {
            backgroundview.backgroundColor = AppColors.background
        }
        for cards in AllCardViews {
            cards.applyShadow()
            cards.backgroundColor = AppColors.card
        }
        typeSegment.backgroundColor          = AppColors.sectionBackground
        typeSegment.selectedSegmentTintColor = AppColors.brandLight
        nameTextField.backgroundColor        = AppColors.card
        amountTextField.backgroundColor      = AppColors.card
    }

    func setupPickers() {
        intervalPicker.delegate   = self
        intervalPicker.dataSource = self
        intervalPickerHeight.constant = 0
    }

    func setupDatePicker() {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        selectedDateLabel.text = fmt.string(from: Date())
        datePickerHeight.constant = 0
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
    }

    func setupGestures() {
        let intervalTap = UITapGestureRecognizer(target: self, action: #selector(intervalTapped))
        intervalRowStack.addGestureRecognizer(intervalTap)
        intervalRowStack.isUserInteractionEnabled = true

        let dueDateTap = UITapGestureRecognizer(target: self, action: #selector(dueDateTapped))
        dueDateRowStack.addGestureRecognizer(dueDateTap)
        dueDateRowStack.isUserInteractionEnabled = true
    }

    func applyModeUI() {
        switch mode {
        case .subscription:
            typeSegment.selectedSegmentIndex = 0
            intervals = ["Weekly", "Monthly", "Quarterly", "Half-Yearly", "Yearly"]
            intervalLabel.text = "Weekly"
            intervalTitleLabel.text = "Interval"
            dueDateTitleLabel.text  = "Due date"
            alertSectionView.isHidden    = false
            autoAddSectionView.isHidden  = false
            if let idx = intervals.firstIndex(of: "Monthly") {
                intervalPicker.selectRow(idx, inComponent: 0, animated: false)
            }
            notesTextView.text = ""

        case .bill:
            title = "Add Bill"
            typeSegment.selectedSegmentIndex = 1
            intervals = ["Monthly", "Quarterly", "Half-Yearly", "Yearly"]
            intervalTitleLabel.text = "Duration"
            dueDateTitleLabel.text  = "Payment Date"
            alertSectionView.isHidden    = true
            autoAddSectionView.isHidden  = true
            if let idx = intervals.firstIndex(of: "Monthly") {
                intervalPicker.selectRow(idx, inComponent: 0, animated: false)
            }
            notesTextView.text = ""
        }
        intervalPicker.reloadAllComponents()
    }

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        mode = sender.selectedSegmentIndex == 0 ? .subscription : .bill
        applyModeUI()
    }

    @IBAction func cancelButton(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func saveButton(_ sender: Any) {
        guard
            let name = nameTextField.text,
            !name.trimmingCharacters(in: .whitespaces).isEmpty,
            let amountText = amountTextField.text,
            let amount = Double(amountText.filter { $0.isNumber || $0 == "." }),
            amount > 0
        else {
            showValidationError()
            return
        }

        let selectedRow      = intervalPicker.selectedRow(inComponent: 0)
        let selectedInterval = intervals[selectedRow]
        let note             = notesTextView.text?.trimmingCharacters(in: .whitespaces)
        let cleanNote        = note?.isEmpty == true ? nil : note
        let db               = DatabaseManager.shared

        switch mode {
        case .subscription:
            let subscriptionCategoryId = db.ensureCategory(
                name: "Subscriptions",
                color: "#B983FF",
                icon: "play.rectangle.fill",
                budget: 0
            )

            if let subscriptionCategoryId {
                db.linkCategoryToCurrentBudget(categoryId: subscriptionCategoryId)
            }

            db.insertRecurringPayment(
                name:               name.trimmingCharacters(in: .whitespaces),
                categoryId:         subscriptionCategoryId,
                duration:           paymentDuration(from: selectedInterval),
                amount:             amount,
                nextDate:           datePicker.date,
                icon:               "play.rectangle.fill",
                isAlertEnabled:     alertToggle?.isOn ?? true,
                isAddAutomatically: autoAddToggle?.isOn ?? true,
                note:               cleanNote
            )

        case .bill:
            let utilityCategoryId = db.ensureCategory(
                name: "Utilities",
                color: "#FFD93D",
                icon: "bolt.fill",
                budget: 0
            )

            if let utilityCategoryId {
                db.linkCategoryToCurrentBudget(categoryId: utilityCategoryId)
            }

            if let utilityCategoryId {
                db.insertBill(
                name:       name.trimmingCharacters(in: .whitespaces),
                icon:       "doc.text.fill",
                categoryId: utilityCategoryId,
                amount:     amount,
                billDate:   datePicker.date,
                range:      billingRange(from: selectedInterval),
                note:       cleanNote
            )
            }
        }

        dismiss(animated: true) {
            self.onEntrySaved?()
            NotificationCenter.default.post(name: .categoryDataDidChange, object: nil)
            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
        }
    }

    private func paymentDuration(from string: String) -> PaymentDuration {
        switch string {
        case "Weekly":  return .weekly
        case "Yearly":  return .yearly
        default:        return .monthly
        }
    }

    private func billingRange(from string: String) -> BillingRange {
        switch string {
        case "Yearly":  return .yearly
        default:        return .monthly
        }
    }

    private func showValidationError() {
        let alert = UIAlertController(
            title: "Missing Information",
            message: "Please enter a name and a valid amount.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc func intervalTapped() {
        view.endEditing(true)
        if !pickerVisible {
            datePickerVisible = false
            datePickerHeight.constant = 0
        }
        pickerVisible.toggle()
        intervalPickerHeight.constant = pickerVisible ? 160 : 0
    }

    @objc func dueDateTapped() {
        view.endEditing(true)
        if !datePickerVisible {
            pickerVisible = false
            intervalPickerHeight.constant = 0
        }
        datePickerVisible.toggle()
        datePickerHeight.constant = datePickerVisible ? 216 : 0
    }

    func showDatePicker(_ show: Bool) {
        datePickerVisible = show
        datePickerHeight.constant = show ? 216 : 0
    }

    @objc func dateChanged() {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        selectedDateLabel.text = fmt.string(from: datePicker.date)
    }
}

extension AddSubsAndBillsViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        intervals.count
    }
}

extension AddSubsAndBillsViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        intervals[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        intervalLabel.text = intervals[row]
    }
}
