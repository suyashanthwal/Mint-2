

import UIKit

protocol AddMoneyAlertViewControllerDelegate: AnyObject {
    func didAddMoney(amount: Double, goalId: UUID)
}

class AddMoneyAlertViewController: UIViewController {

    @IBOutlet weak var GoalNameLabel: UILabel!
    @IBOutlet weak var EntryAmountTextField: UITextField!
    @IBOutlet weak var LeftAmountLabel: UILabel!
    @IBOutlet weak var Amount500Button: UIButton!
    @IBOutlet weak var Amount1000Button: UIButton!
    @IBOutlet weak var Amount2000Button: UIButton!
    @IBOutlet weak var Amount5000Button: UIButton!

    
    
    @IBAction func DoneButtonTapped(_ sender: Any) {
        guard let text = EntryAmountTextField.text,
                  let amount = Double(text),
                  amount > 0,
                  amount <= budgetRemaining else {
                return
            }

            delegate?.didAddMoney(amount: amount, goalId: goal.id)
            dismiss(animated: true)
    }

    var goal: Goal!
    var budgetRemaining: Double = 0
    weak var delegate: AddMoneyAlertViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        setupUI()
        EntryAmountTextField.returnKeyType = .done
        EntryAmountTextField.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        EntryAmountTextField.becomeFirstResponder()
    }

    private func setupUI() {
        view.backgroundColor = AppColors.background
        GoalNameLabel.text = goal.name
        LeftAmountLabel.text = "Budget left: ₹\(Int(budgetRemaining))"
        EntryAmountTextField.keyboardType = .numberPad
        
        Amount500Button.backgroundColor = AppColors.brandLight
        Amount500Button.setTitleColor(AppColors.brand, for: .normal)
        Amount1000Button.backgroundColor = AppColors.brandLight
        Amount1000Button.setTitleColor(AppColors.brand, for: .normal)
        Amount2000Button.backgroundColor = AppColors.brandLight
        Amount2000Button.setTitleColor(AppColors.brand, for: .normal)
        Amount5000Button.backgroundColor = AppColors.brandLight
    }

    @IBAction func amount500Tapped(_ sender: UIButton) {
        EntryAmountTextField.text = "500"
    }

    @IBAction func amount1000Tapped(_ sender: UIButton) {
        EntryAmountTextField.text = "1000"
    }

    @IBAction func amount2000Tapped(_ sender: UIButton) {
        EntryAmountTextField.text = "2000"
    }

    @IBAction func amount5000Tapped(_ sender: UIButton) {

        EntryAmountTextField.text = "5000"
    }

    @IBAction func confirmTapped(_ sender: UIButton) {
        guard let text = EntryAmountTextField.text,
              let amount = Double(text),
              amount > 0,
              amount <= budgetRemaining else {
            return
        }

        delegate?.didAddMoney(amount: amount, goalId: goal.id)
        dismiss(animated: true)
    }

    @IBAction func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
}
extension AddMoneyAlertViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        DoneButtonTapped(textField)
        return true
    }
}
