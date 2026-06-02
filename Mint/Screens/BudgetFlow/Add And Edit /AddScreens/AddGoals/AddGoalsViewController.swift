
import PhotosUI
import UIKit

class AddGoalsViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var targetDateTitleLabel: UILabel!
    @IBOutlet weak var targetDateValueLabel: UILabel!
    @IBOutlet weak var targetDateRowStack: UIStackView!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var datePickerHeight: NSLayoutConstraint!
    @IBOutlet weak var monthlyTargetTextField: UITextField!
    @IBOutlet weak var notesTextView: UITextField!
    @IBOutlet weak var goalPhotoImageView: UIImageView!
    @IBOutlet weak var goalPhotoButton: UIButton!

    @IBOutlet var AllBackgroundView: [UIView]!
    @IBOutlet var AllCardsView: [UIView]!
    @IBOutlet var AllStackViews: [UIStackView]!

    var onGoalSaved: (() -> Void)?
    var datePickerVisible = false
    private var selectedGoalImage: UIImage?
    private var userEditedMonthlyTarget = false

    override func viewDidLoad() {
        super.viewDidLoad()
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        setupUI()
        setupDatePicker()
        setupGestures()
    }

    @IBAction func cancelButton(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func saveButton(_ sender: Any) {
        guard
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

        let minimumMonthlyGoal = requiredMonthlyTarget(
            targetAmount: targetAmount,
            currentlySaved: 0,
            targetDate: datePicker.date
        )

        guard monthlyGoal >= minimumMonthlyGoal else {
            showMonthlyTargetTooLowError(minimumMonthlyGoal)
            return
        }

        if let id = DatabaseManager.shared.insertGoal(
            name:         name.trimmingCharacters(in: .whitespaces),
            targetAmount: targetAmount,
            targetDate:   datePicker.date,
            monthlyGoal:  monthlyGoal,
            iconName:     "star.fill"
        ) {
            DatabaseManager.shared.linkGoalToCurrentBudget(goalId: id)
            if let selectedGoalImage {
                GoalImageStore.save(selectedGoalImage, for: id)
            }
        }

        dismiss(animated: true) {
            self.onGoalSaved?()
            NotificationCenter.default.post(name: .goalDataDidChange, object: nil)
            NotificationCenter.default.post(name: .budgetDataDidChange, object: nil)
        }
    }

    private func showValidationError() {
        let alert = UIAlertController(
            title: "Incorrect Information",
            message: "Please enter all the information correctly.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showMonthlyTargetTooLowError(_ minimumAmount: Double) {
        let roundedMinimum = Int(minimumAmount)
        let alert = UIAlertController(
            title: "Monthly Target Too Low",
            message: "Minimum monthly target is ₹\(roundedMinimum) to reach this goal by the selected date.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Use ₹\(roundedMinimum)", style: .default) { [weak self] _ in
            self?.monthlyTargetTextField.text = String(roundedMinimum)
            self?.userEditedMonthlyTarget = false
        })
        alert.addAction(UIAlertAction(title: "Change Date", style: .cancel))

        present(alert, animated: true)
    }
}

extension AddGoalsViewController {

    func setupUI() {
        view.backgroundColor = AppColors.card
        for backgroundview in AllBackgroundView {
            backgroundview.backgroundColor = AppColors.card
        }
        for views in AllCardsView {
            views.applyAddEditInputContainerStyle()
        }
        for stackView in AllStackViews {
            stackView.backgroundColor = AppColors.inputBackground
        }
        nameTextField.applyAddEditInputStyle()
        amountTextField.applyAddEditInputStyle(keyboardType: .numberPad)
        monthlyTargetTextField.applyAddEditInputStyle(keyboardType: .numberPad)
        monthlyTargetTextField.placeholder = "Auto calculated"
        amountTextField.addTarget(self, action: #selector(goalAmountChanged), for: .editingChanged)
        monthlyTargetTextField.addTarget(self, action: #selector(monthlyTargetChanged), for: .editingChanged)
        notesTextView.applyAddEditInputStyle()
        targetDateTitleLabel.textColor = AppColors.textPrimary
        targetDateValueLabel.textColor = AppColors.textSecondary
        datePicker.applyMintDatePickerStyle()
        notesTextView.layer.cornerRadius = 12
        notesTextView.clipsToBounds = true
        view.applyMintTypography()
        datePicker.applyMintDatePickerStyle()
        setupPhotoSection()
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

    private func setupPhotoSection() {
        goalPhotoImageView.backgroundColor = AppColors.inputBackground
        goalPhotoImageView.layer.cornerRadius = 16
        goalPhotoImageView.layer.masksToBounds = true
        goalPhotoImageView.contentMode = .scaleAspectFit
        goalPhotoImageView.tintColor = AppColors.textSecondary
        goalPhotoImageView.image = UIImage(systemName: "photo.on.rectangle.angled")

        goalPhotoButton.layer.cornerRadius = 16
        goalPhotoButton.layer.cornerCurve = .continuous
        goalPhotoButton.layer.borderWidth = 1
        goalPhotoButton.layer.borderColor = AppColors.brand.withAlphaComponent(0.45).cgColor
        goalPhotoButton.setTitleColor(AppColors.textPrimary, for: .normal)
        goalPhotoButton.backgroundColor = AppColors.brand.withAlphaComponent(0.12)
    }
}

extension AddGoalsViewController {

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
        updateSuggestedMonthlyTargetIfNeeded()
    }

    @objc func goalAmountChanged() {
        updateSuggestedMonthlyTargetIfNeeded()
    }

    @objc func monthlyTargetChanged() {
        userEditedMonthlyTarget = true
    }

    func updateDateLabel(_ date: Date) {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        targetDateValueLabel.text = fmt.string(from: date)
    }

    private func updateSuggestedMonthlyTargetIfNeeded() {
        guard !userEditedMonthlyTarget else { return }
        guard let targetAmount = parsedAmount(from: amountTextField.text), targetAmount > 0 else {
            monthlyTargetTextField.text = nil
            return
        }

        let minimumMonthlyGoal = requiredMonthlyTarget(
            targetAmount: targetAmount,
            currentlySaved: 0,
            targetDate: datePicker.date
        )

        monthlyTargetTextField.text = String(Int(minimumMonthlyGoal))
    }

    private func parsedAmount(from text: String?) -> Double? {
        guard let text else { return nil }
        return Double(text.filter { $0.isNumber || $0 == "." })
    }

    private func requiredMonthlyTarget(
        targetAmount: Double,
        currentlySaved: Double,
        targetDate: Date
    ) -> Double {
        let remainingAmount = max(targetAmount - currentlySaved, 0)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: targetDate)
        let daysRemaining = max(calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0, 1)
        let monthsRemaining = max(Int(ceil(Double(daysRemaining) / 30.0)), 1)

        return ceil(remainingAmount / Double(monthsRemaining))
    }

    @IBAction func choosePhotoTapped(_ sender: UIButton) {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
}

extension AddGoalsViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self, let image = object as? UIImage, error == nil else { return }
            Task { [weak self] in
                guard let self else { return }
                let processedImage = await GoalImageCutoutProcessor.process(image)
                await MainActor.run {
                    self.selectedGoalImage = processedImage
                    self.goalPhotoImageView.image = processedImage
                    self.goalPhotoImageView.contentMode = .scaleAspectFit
                    self.goalPhotoButton.setTitle("Change Photo", for: .normal)
                }
            }
        }
    }
}
