//
//  AddGoalsViewController.swift
//  EditPages
//
//  Created by Anushk Barmola on 06/02/26.
//

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

    @IBOutlet var AllBackgroundView: [UIView]!
    @IBOutlet var AllCardsView: [UIView]!
    @IBOutlet var AllStackViews: [UIStackView]!

    var onGoalSaved: (() -> Void)?
    var datePickerVisible = false

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

        if let id = DatabaseManager.shared.insertGoal(
            name:         name.trimmingCharacters(in: .whitespaces),
            targetAmount: targetAmount,
            targetDate:   datePicker.date,
            monthlyGoal:  monthlyGoal,
            iconName:     "star.fill"
        ) {
            DatabaseManager.shared.linkGoalToCurrentBudget(goalId: id)
        }

        // 🔥 IMPORTANT: call BEFORE dismiss
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
}

// MARK: - UI Setup

extension AddGoalsViewController {

    func setupUI() {
        view.backgroundColor = AppColors.card
        for views in AllCardsView {
            views.backgroundColor = AppColors.card
            views.applyShadow()
        }
        for backgroundview in AllBackgroundView {
            backgroundview.backgroundColor = AppColors.background
        }
        nameTextField.backgroundColor = AppColors.card
        amountTextField.backgroundColor = AppColors.card
        amountTextField.keyboardType = .numberPad
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

// MARK: - Date Picker

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
    }

    func updateDateLabel(_ date: Date) {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        targetDateValueLabel.text = fmt.string(from: date)
    }
}
