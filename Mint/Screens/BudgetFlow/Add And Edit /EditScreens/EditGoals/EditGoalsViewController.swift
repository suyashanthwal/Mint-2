
import PhotosUI
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
    @IBOutlet weak var goalPhotoImageView: UIImageView!
    @IBOutlet weak var goalPhotoButton: UIButton!

    @IBOutlet var AllBackgroundViews: [UIView]!
    @IBOutlet var AllInsideViews: [UIView]!

    var goal: Goal?
    var onGoalUpdated: (() -> Void)?
    var datePickerVisible = false
    private var selectedGoalImage: UIImage?

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
            isOnHold:       goal.isOnHold,
            completedOn:    goal.completedOn
        )

        if let selectedGoalImage {
            GoalImageStore.save(selectedGoalImage, for: goal.id)
        }

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
        view.backgroundColor = AppColors.card
        for views in AllBackgroundViews {
            views.backgroundColor = AppColors.card
        }
        for views in AllInsideViews {
            views.applyAddEditInputContainerStyle()
        }
        nameTextField.applyAddEditInputStyle()
        amountTextField.applyAddEditInputStyle(keyboardType: .numberPad)
        monthlyTargetTextField.applyAddEditInputStyle(keyboardType: .numberPad)
        notesTextView.applyAddEditInputStyle()
        targetDateTitleLabel.textColor = AppColors.textPrimary
        targetDateValueLabel.textColor = AppColors.textSecondary
        totalSavedLabel.textColor = AppColors.textPrimary
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

extension EditGoalsViewController {

    func loadGoal() {
        guard let goal = goal else { return }
        var goalWithImage = goal
        var goalsToAttach = [goalWithImage]
        GoalImageStore.attachSavedImages(to: &goalsToAttach)
        goalWithImage = goalsToAttach[0]

        title = goalWithImage.name
        nameTextField.text          = goalWithImage.name
        amountTextField.text        = String(Int(goalWithImage.targetAmount))
        monthlyTargetTextField.text = String(Int(goalWithImage.monthlyGoal))
        totalSavedLabel.text        = "Saved: ₹\(Int(goalWithImage.currentlySaved))"
        notesTextView.text          = nil

        datePicker.date = goalWithImage.targetDate
        updateDateLabel(goalWithImage.targetDate)

        if let loadedImage = GoalImageStore.loadSavedImage(for: goalWithImage) {
            goalPhotoImageView.image = loadedImage.image
            goalPhotoImageView.contentMode = .scaleAspectFit
            goalPhotoButton.setTitle("Change Photo", for: .normal)
        }
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

    @IBAction func choosePhotoTapped(_ sender: UIButton) {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
}

extension EditGoalsViewController: PHPickerViewControllerDelegate {

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
