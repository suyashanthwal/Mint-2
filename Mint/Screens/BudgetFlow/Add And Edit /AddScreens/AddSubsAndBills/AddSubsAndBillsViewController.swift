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
    @IBOutlet weak var iconPickerStackView: UIStackView!
    @IBOutlet weak var iconPickerImageView: UIImageView!
    @IBOutlet weak var iconPickerLabel: UILabel!
    @IBOutlet weak var iconCollectionView: UICollectionView!
    @IBOutlet weak var iconCollectionViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet var AllBackgroundViews: [UIView]!
    @IBOutlet var AllCardViews: [UIView]!

    var intervals: [String] = []
    var pickerVisible = false
    var datePickerVisible = false

    private var isIconPickerExpanded = false
    private let collapsedIconPickerHeight: CGFloat = 0
    private let expandedIconPickerHeight: CGFloat = 400
    private var selectedIconName: String?
    private let iconCategories = CategoryData.subsAndBillsIconCategories

    override func viewDidLoad() {
        super.viewDidLoad()
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        setupUI()
        setupPickers()
        setupIconCollectionView()
        setupGestures()
        setupDatePicker()
        applyModeUI()
    }

    func setupUI() {
        view.backgroundColor = AppColors.card
        for backgroundview in AllBackgroundViews {
            backgroundview.backgroundColor = AppColors.card
        }
        for cards in AllCardViews {
            cards.applyAddEditInputContainerStyle()
        }
        typeSegment.backgroundColor          = AppColors.sectionBackground
        typeSegment.selectedSegmentTintColor = AppColors.brandLight
        nameTextField.applyAddEditInputStyle()
        amountTextField.applyAddEditInputStyle(keyboardType: .numberPad)
        notesTextView.applyAddEditInputStyle()
        intervalLabel.textColor              = AppColors.textPrimary
        selectedDateLabel.textColor          = AppColors.textPrimary
        intervalTitleLabel.textColor         = AppColors.textPrimary
        dueDateTitleLabel.textColor          = AppColors.textPrimary
        datePicker.tintColor                 = AppColors.brand
        autoAddToggle.onTintColor            = AppColors.brand
        alertToggle.onTintColor              = AppColors.brand
        iconPickerImageView.tintColor        = AppColors.brand
        iconPickerLabel.textColor            = AppColors.textPrimary
        iconCollectionView.backgroundColor   = AppColors.inputBackground
        iconCollectionView.clipsToBounds     = true
        iconCollectionViewHeightConstraint.constant = collapsedIconPickerHeight
        iconCollectionView.isHidden = true
        styleIconPickerRow()
        setSelectedIcon(defaultIconName)
        view.applyMintTypography()
    }

    private func styleIconPickerRow() {
        iconPickerStackView.backgroundColor = AppColors.inputBackground
        iconPickerStackView.superview?.backgroundColor = AppColors.inputBackground

        let rowContainer = iconPickerStackView.superview?.superview
        rowContainer?.applyAddEditInputContainerStyle()
        rowContainer?.layer.cornerRadius = 16
    }

    func setupPickers() {
        intervalPicker.delegate   = self
        intervalPicker.dataSource = self
        intervalPickerHeight.constant = 0
    }

    private func setupIconCollectionView() {
        iconCollectionView.delegate = self
        iconCollectionView.dataSource = self

        iconCollectionView.register(
            UINib(nibName: "IconCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "IconCell"
        )
        iconCollectionView.register(
            UINib(nibName: "IconHeaderCollectionReusableView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "IconHeaderView"
        )

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.headerReferenceSize = CGSize(width: iconCollectionView.frame.width, height: 40)
        iconCollectionView.collectionViewLayout = layout
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

        let iconTap = UITapGestureRecognizer(target: self, action: #selector(iconPickerTapped))
        iconPickerStackView.addGestureRecognizer(iconTap)
        iconPickerStackView.isUserInteractionEnabled = true
    }

    func applyModeUI() {
        switch mode {
        case .subscription:
            title = "Add Subs and Bills"
            typeSegment.selectedSegmentIndex = 0
            intervals = ["Daily", "Weekly", "Monthly", "Quarterly", "Half-Yearly", "Yearly"]
            intervalLabel.text = "Monthly"
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
            intervals = ["Daily", "Weekly", "Monthly", "Quarterly", "Half-Yearly", "Yearly"]
            intervalLabel.text = "Monthly"
            intervalTitleLabel.text = "Duration"
            dueDateTitleLabel.text  = "Payment Date"
            alertSectionView.isHidden    = false
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

            let insertedId = db.insertRecurringPayment(
                name:               name.trimmingCharacters(in: .whitespaces),
                categoryId:         subscriptionCategoryId,
                duration:           paymentDuration(from: selectedInterval),
                amount:             amount,
                nextDate:           datePicker.date,
                icon:               selectedIconName ?? defaultIconName,
                isAlertEnabled:     alertToggle?.isOn ?? true,
                isAddAutomatically: autoAddToggle?.isOn ?? true,
                note:               cleanNote
            )

            if let insertedId {
                let reminder = RecurringPayment(
                    id: insertedId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    categoryId: subscriptionCategoryId,
                    duration: paymentDuration(from: selectedInterval),
                    amount: amount,
                    nextDate: datePicker.date,
                    isActive: true,
                    isAlertEnabled: alertToggle?.isOn ?? true,
                    isAddAutomatically: autoAddToggle?.isOn ?? true,
                    icon: selectedIconName ?? defaultIconName,
                    note: cleanNote
                )
                BillSubscriptionReminderManager.shared.scheduleReminder(for: reminder)
            }

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
                let insertedId = db.insertBill(
                    name:       name.trimmingCharacters(in: .whitespaces),
                    icon:       selectedIconName ?? defaultIconName,
                    categoryId: utilityCategoryId,
                    amount:     amount,
                    billDate:   datePicker.date,
                    range:      billingRange(from: selectedInterval),
                    isAlertEnabled: alertToggle?.isOn ?? true,
                    note:       cleanNote
                )

                if let insertedId {
                    let reminder = Bill(
                        id: insertedId,
                        name: name.trimmingCharacters(in: .whitespaces),
                        icon: selectedIconName ?? defaultIconName,
                        categoryId: utilityCategoryId,
                        amount: amount,
                        billDate: datePicker.date,
                        range: billingRange(from: selectedInterval),
                        isPaid: false,
                        isAlertEnabled: alertToggle?.isOn ?? true,
                        note: cleanNote
                    )
                    BillSubscriptionReminderManager.shared.scheduleReminder(for: reminder)
                }
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
        case "Daily":       return .daily
        case "Weekly":      return .weekly
        case "Quarterly":   return .quarterly
        case "Half-Yearly": return .halfYearly
        case "Yearly":      return .yearly
        default:            return .monthly
        }
    }

    private func billingRange(from string: String) -> BillingRange {
        switch string {
        case "Daily":       return .daily
        case "Weekly":      return .weekly
        case "Quarterly":   return .quarterly
        case "Half-Yearly": return .halfYearly
        case "Yearly":      return .yearly
        default:            return .monthly
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

    @objc private func iconPickerTapped() {
        isIconPickerExpanded.toggle()
        UIView.animate(withDuration: 0.3) {
            self.iconCollectionViewHeightConstraint.constant = self.isIconPickerExpanded
                ? self.expandedIconPickerHeight
                : self.collapsedIconPickerHeight
            self.iconCollectionView.isHidden = !self.isIconPickerExpanded
            self.view.layoutIfNeeded()
        }
    }

    private var defaultIconName: String {
        Array(iconCategories.values).first?.first ?? "doc.text.fill"
    }

    private func setSelectedIcon(_ iconName: String) {
        selectedIconName = iconName
        iconPickerImageView.image = UIImage(systemName: iconName)
        iconPickerImageView.tintColor = AppColors.brand
        iconPickerLabel.text = formatIconName(iconName)
    }

    private func formatIconName(_ systemName: String) -> String {
        let words = systemName.split(separator: ".")
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
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

extension AddSubsAndBillsViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        iconCategories.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Array(iconCategories.values)[section].count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "IconCell",
            for: indexPath
        ) as! IconCollectionViewCell
        let iconName = Array(iconCategories.values)[indexPath.section][indexPath.item]
        cell.configure(with: iconName)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "IconHeaderView",
            for: indexPath
        ) as! IconHeaderCollectionReusableView
        header.configure(with: Array(iconCategories.keys)[indexPath.section])
        return header
    }
}

extension AddSubsAndBillsViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let iconName = Array(iconCategories.values)[indexPath.section][indexPath.item]
        setSelectedIcon(iconName)
        iconPickerTapped()
    }
}

extension AddSubsAndBillsViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: 50, height: 50)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
    }
}
