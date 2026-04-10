//
//  SetBudgetViewController.swift
//  Mint
//
//  Created by AnushkB on 01/04/26.
//

import UIKit

class SetBudgetViewController: UIViewController {

    @IBOutlet weak var allocatedBudget: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        allocatedBudget.keyboardType = .decimalPad
        enableKeyboardDismissOnBackgroundTapAndSwipe()
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
}
