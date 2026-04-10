import UIKit

class EditSubsAndBillsViewController: UIViewController {

    var mode: EntryMode = .subscription
    // Pass the full model objects (with their UUIDs) instead of array indices
    var recurringPayment: RecurringPayment?
    var bill: Bill?
    var onEntryUpdated: (() -> Void)?

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

    @IBOutlet weak var intervalTitleLabel: UILabel!
    @IBOutlet weak var dueDateTitleLabel: UILabel!
    @IBOutlet weak var alertSectionView: UIView!
    @IBOutlet weak var autoAddSectionView: UIView!
    @IBOutlet weak var notesTextView: UITextField!

    @IBOutlet weak var alertToggle: UISwitch!
    @IBOutlet weak var autoAddToggle: UISwitch!
    @IBOutlet weak var isActiveToggle: UISwitch!
    @IBOutlet weak var isActiveSectionView: UIView!

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
        loadEntry()
    }

    func setupUI() {
        for backgroundView in AllBackgroundViews {
            backgroundView.backgroundColor = AppColors.background
        }
        for card in AllCardViews {
            card.backgroundColor = AppColors.card
            card.applyShadow()
        }
        nameTextField.backgroundColor   = AppColors.card
        amountTextField.backgroundColor = AppColors.card
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
            intervalTitleLabel.text = "Interval"
            dueDateTitleLabel.text  = "Due date"
            alertSectionView.isHidden    = false
            autoAddSectionView.isHidden  = false
            isActiveSectionView.isHidden = false

        case .bill:
            typeSegment.selectedSegmentIndex = 1
            intervals = ["Monthly", "Quarterly", "Half-Yearly", "Yearly"]
            intervalTitleLabel.text = "Duration"
            dueDateTitleLabel.text  = "Payment Date"
            alertSectionView.isHidden    = true
            autoAddSectionView.isHidden  = true
            isActiveSectionView.isHidden = true
        }
        intervalPicker.reloadAllComponents()
    }

    // MARK: - Load existing entry into UI

    func loadEntry() {
        switch mode {
        case .subscription:
            guard let payment = recurringPayment else { return }
            nameTextField.text   = payment.name
            amountTextField.text = payment.amount.truncatingRemainder(dividingBy: 1) == 0
                                    ? String(Int(payment.amount))
                                    : String(payment.amount)
            notesTextView.text          = payment.note ?? ""
            alertToggle?.isOn           = payment.isAlertEnabled
            autoAddToggle?.isOn         = payment.isAddAutomatically
            isActiveToggle?.isOn        = payment.isActive

            let durationString = durationDisplayString(payment.duration)
            intervalLabel.text = durationString
            if let idx = intervals.firstIndex(of: durationString) {
                intervalPicker.selectRow(idx, inComponent: 0, animated: false)
            }
            datePicker.date = payment.nextDate
            updateDateLabel(payment.nextDate)

        case .bill:
            guard let bill = bill else { return }
            nameTextField.text   = bill.name
            amountTextField.text = bill.amount.truncatingRemainder(dividingBy: 1) == 0
                                    ? String(Int(bill.amount))
                                    : String(bill.amount)
            notesTextView.text = bill.note ?? ""

            let rangeString = rangeDisplayString(bill.range)
            intervalLabel.text = rangeString
            if let idx = intervals.firstIndex(of: rangeString) {
                intervalPicker.selectRow(idx, inComponent: 0, animated: false)
            }
            datePicker.date = bill.billDate
            updateDateLabel(bill.billDate)
        }
    }

    // MARK: - IBActions

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
        let selectedString   = intervals[selectedRow]
        let note             = notesTextView.text?.trimmingCharacters(in: .whitespaces)
        let cleanNote        = note?.isEmpty == true ? nil : note
        let db               = DatabaseManager.shared

        switch mode {
        case .subscription:
            guard let payment = recurringPayment else { return }
            db.updateRecurringPayment(
                id:                 payment.id,
                name:               name.trimmingCharacters(in: .whitespaces),
                duration:           paymentDuration(from: selectedString),
                amount:             amount,
                nextDate:           datePicker.date,
                isAlertEnabled:     alertToggle?.isOn ?? true,
                isAddAutomatically: autoAddToggle?.isOn ?? true,
                isActive:           isActiveToggle?.isOn ?? true,
                note:               cleanNote
            )

        case .bill:
            guard let bill = bill else { return }
            db.updateBill(
                id:       bill.id,
                name:     name.trimmingCharacters(in: .whitespaces),
                amount:   amount,
                billDate: datePicker.date,
                range:    billingRange(from: selectedString),
                note:     cleanNote
            )
        }

        dismiss(animated: true) {
            self.onEntryUpdated?()
            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
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

    // MARK: - Picker / DatePicker toggle

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

    @objc func dateChanged() {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        selectedDateLabel.text = fmt.string(from: datePicker.date)
    }

    func updateDateLabel(_ date: Date) {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        selectedDateLabel.text = fmt.string(from: date)
    }

    // MARK: - Enum Helpers

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

    private func durationDisplayString(_ duration: PaymentDuration) -> String {
        switch duration {
        case .daily:   return "Weekly"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }

    private func rangeDisplayString(_ range: BillingRange) -> String {
        switch range {
        case .daily:   return "Monthly"
        case .weekly:  return "Monthly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }
}

// MARK: - UIPickerViewDataSource

extension EditSubsAndBillsViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        intervals.count
    }
}

// MARK: - UIPickerViewDelegate

extension EditSubsAndBillsViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        intervals[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        intervalLabel.text = intervals[row]
    }
}
