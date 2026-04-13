
import UIKit

class EditGoalsViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var targetDateTitleLabel: UILabel!
    @IBOutlet weak var targetDateValueLabel: UILabel!
    @IBOutlet weak var targetDateRowStack: UIStackView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var datePickerHeight: NSLayoutConstraint!
    @IBOutlet weak var monthlyTargetTextField: UITextField!
    @IBOutlet weak var notesTextView: UITextField!
    @IBOutlet weak var totalSavedLabel: UILabel!

    @IBOutlet var AllBackgroundViews: [UIView]!
    @IBOutlet var AllInsideViews: [UIView]!

    var goal: Goal?
    var onGoalUpdated: (() -> Void)?
    var datePickerVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        setupUI()
        setupDatePicker()
        setupGestures()
        loadGoal()
    }

    @IBAction func cancelButton(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func saveButton(_ sender: Any) {
        guard
            let goal = goal,
            let name = nameTextField.text,
            !name.trimmingCharacters(in: .whitespaces).isEmpty,
            let amountText = amountTextField.text,
            let targetAmount = Double(amountText.filter { $0.isNumber || $0 == "." }),
            let monthlyText = monthlyTargetTextField.text,
            let monthlyGoal = Double(monthlyText.filter { $0.isNumber || $0 == "." }),
            targetAmount > 0, monthlyGoal > 0
        else {
            showValidationError()
            return
        }

        DatabaseManager.shared.updateGoal(
            id:             goal.id,
            name:           name.trimmingCharacters(in: .whitespaces),
            targetAmount:   targetAmount,
            currentlySaved: goal.currentlySaved,
            targetDate:     datePicker.date,
            monthlyGoal:    monthlyGoal,
            iconName:       goal.iconName,
            imageName:      goal.imageName,
            isCompleted:    goal.isCompleted,
            completedOn:    goal.completedOn
        )

        onGoalUpdated?()
        dismiss(animated: true) {
            NotificationCenter.default.post(name: .goalDataDidChange, object: nil)
            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
        }
    }

    private func showValidationError() {
        let alert = UIAlertController(
            title: "Missing Information",
            message: "Please enter a name, target amount, and monthly target.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension EditGoalsViewController {

    func setupUI() {
        for views in AllBackgroundViews {
            views.backgroundColor = AppColors.background
        }
        for views in AllInsideViews {
            views.backgroundColor = AppColors.card
            views.applyShadow()
        }
        amountTextField.keyboardType = .numberPad
        amountTextField.backgroundColor = AppColors.card
        nameTextField.backgroundColor = AppColors.card
        monthlyTargetTextField.keyboardType = .numberPad
        notesTextView.layer.cornerRadius = 12
        notesTextView.clipsToBounds = true
    }

    func setupDatePicker() {
        updateDateLabel(datePicker.date)
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
    }

    func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(targetDateTapped))
        targetDateRowStack.addGestureRecognizer(tap)
        targetDateRowStack.isUserInteractionEnabled = true
    }
}

extension EditGoalsViewController {

    func loadGoal() {
        guard let goal = goal else { return }

        title = goal.name
        nameTextField.text          = goal.name
        amountTextField.text        = String(Int(goal.targetAmount))
        monthlyTargetTextField.text = String(Int(goal.monthlyGoal))
        totalSavedLabel.text        = "Saved: ₹\(Int(goal.currentlySaved))"
        notesTextView.text          = nil

        datePicker.date = goal.targetDate
        updateDateLabel(goal.targetDate)
    }
}

extension EditGoalsViewController {

    @objc func targetDateTapped() {
        view.endEditing(true)
        datePickerVisible.toggle()
        UIView.animate(withDuration: 0.25) {
            self.datePickerHeight.constant = self.datePickerVisible ? 216 : 0
            self.view.layoutIfNeeded()
        }
    }

    @objc func dateChanged() {
        updateDateLabel(datePicker.date)
    }

    func updateDateLabel(_ date: Date) {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        targetDateValueLabel.text = fmt.string(from: date)
    }
}
