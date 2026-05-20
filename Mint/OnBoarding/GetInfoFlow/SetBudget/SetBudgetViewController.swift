
import UIKit

class SetBudgetViewController: UIViewController {

    @IBOutlet weak var allocatedBudget: UITextField!
    @IBOutlet private weak var monthlyBudgetView: UIView!
    private var monthlyBudgetRestingFrameInView: CGRect = .zero

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        allocatedBudget.keyboardType = .decimalPad
        allocatedBudget.delegate = self
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        observeKeyboard()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard monthlyBudgetView.transform == .identity else { return }
        monthlyBudgetRestingFrameInView = monthlyBudgetView.superview?.convert(monthlyBudgetView.frame, to: view) ?? monthlyBudgetView.frame
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        let amountText = allocatedBudget.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let amount = Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0

        guard amount > 0 else {
            let alert = UIAlertController(
                title: "Invalid Budget",
                message: "Enter your monthly budget before continuing.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return false
        }

        DatabaseManager.shared.upsertCurrentBudget(allocatedBudget: amount)
        return true
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChange(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func handleKeyboardFrameChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let animationCurveRawValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt,
              let keyboardFrameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        else { return }

        let keyboardFrameInView = view.convert(keyboardFrameValue.cgRectValue, from: nil)
        let keyboardTop = keyboardFrameInView.minY
        let budgetFrame = monthlyBudgetRestingFrameInView == .zero
            ? (monthlyBudgetView.superview?.convert(monthlyBudgetView.frame, to: view) ?? monthlyBudgetView.frame)
            : monthlyBudgetRestingFrameInView
        let desiredBottom = keyboardTop - 12

        let targetTransform: CGAffineTransform
        if allocatedBudget.isFirstResponder, budgetFrame.maxY > desiredBottom {
            let shiftY = desiredBottom - budgetFrame.maxY
            targetTransform = CGAffineTransform(translationX: 0, y: shiftY)
        } else {
            targetTransform = .identity
        }

        let animationOptions = UIView.AnimationOptions(rawValue: animationCurveRawValue << 16)
        UIView.animate(withDuration: animationDuration, delay: 0, options: [animationOptions, .beginFromCurrentState]) {
            self.monthlyBudgetView.transform = targetTransform
        }
    }

    private func configureAppearance() {
        view.backgroundColor = AppColors.background
        navigationController?.navigationBar.tintColor = AppColors.textPrimary
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: AppColors.textPrimary,
            .font: MintFont.space(size: 17, weight: .semibold)
        ]

        monthlyBudgetView.backgroundColor = AppColors.inputBackground
        monthlyBudgetView.layer.cornerRadius = 18
        monthlyBudgetView.layer.borderWidth = 1
        monthlyBudgetView.layer.borderColor = AppColors.cardBorder.cgColor

        allocatedBudget.applyAddEditInputStyle(keyboardType: .decimalPad)

        let labels = view.allSubviews.compactMap { $0 as? UILabel }
        if let titleLabel = labels.first(where: { $0.text == "What is your monthly Income?" }) {
            titleLabel.font = MintFont.syne(size: 30, weight: .bold)
            titleLabel.textColor = AppColors.textPrimary
            titleLabel.removeCharacterSpacing()
        }

        if let subtitleLabel = labels.first(where: { $0.text?.contains("This helps us understand your spending") == true }) {
            subtitleLabel.font = MintFont.space(size: 15, weight: .medium)
            subtitleLabel.textColor = AppColors.textSecondary
            subtitleLabel.removeCharacterSpacing()
        }

        if let rupeeLabel = labels.first(where: { $0.text == "₹" }) {
            rupeeLabel.font = MintFont.space(size: 20, weight: .bold)
            rupeeLabel.textColor = AppColors.brand
            rupeeLabel.removeCharacterSpacing()
        }

        let buttons = view.allSubviews.compactMap { $0 as? UIButton }
        buttons.first(where: { $0.currentTitle == "Continue" })?.applyPrimaryOnboardingStyle()
    }
}

extension SetBudgetViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard textField === allocatedBudget else { return }
        view.layoutIfNeeded()
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard textField === allocatedBudget else { return }
        UIView.animate(withDuration: 0.25) {
            self.monthlyBudgetView.transform = .identity
        }
    }
}
