//
//  OngoingGoalCollectionViewCell.swift
//  BudgetApp
//
//  Created by Suyash Anthwal on 02/04/26.
//

import UIKit

class OngoingGoalCollectionViewCell: UICollectionViewCell {
 
    // MARK: - Outlets

    @IBOutlet weak var GoalImage: UIImageView!
    @IBOutlet weak var GoalName: UILabel!
    @IBOutlet weak var TargetDate: UILabel!
    @IBOutlet weak var AcheivedAmount: UILabel!
    @IBOutlet weak var TotalAmount: UILabel!
    @IBOutlet weak var ToGoAmountLabel: UILabel!
    @IBOutlet weak var GoalProgressBar: UIProgressView!
    @IBOutlet weak var AddMoneyButton: UIButton!
    @IBOutlet weak var GoalEditButton: UIButton!

    // MARK: - Callbacks (set by ViewController)
    var onAddMoney: (() -> Void)?
    var onDetail:   (() -> Void)?

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        applyStyle()
    }

    // MARK: - Styling

    private func applyStyle() {
        // Card
        contentView.backgroundColor    = AppColors.card

        GoalName.textColor             = AppColors.textPrimary

        TargetDate.textColor           = AppColors.textSecondary

        AcheivedAmount.textColor       = AppColors.textPrimary

        TotalAmount.textColor          = AppColors.textSecondary

        ToGoAmountLabel.textColor      = AppColors.textSecondary

        // Progress bar
        GoalProgressBar.progressTintColor = AppColors.brand
        GoalProgressBar.trackTintColor    = AppColors.brandLight
        GoalProgressBar.layer.cornerRadius = 3
        GoalProgressBar.clipsToBounds      = true
        GoalProgressBar.transform = GoalProgressBar.transform.scaledBy(x: 1, y: 3)

    }

    func configure(with goal: Goal) {
        GoalName.text    = goal.name
        TargetDate.text  = "Target: \(formattedMonth(goal.targetDate))"

        let achieved     = formatCurrency(goal.currentlySaved)
        let total        = formatCurrency(goal.targetAmount)
        AcheivedAmount.text = achieved
        TotalAmount.text    = "/ \(total)"
        ToGoAmountLabel.text = "\(formatCurrency(goal.amountToGo)) to go"

        GoalProgressBar.setProgress(goal.progress, animated: false)

        // Hero image: prefer named asset, fall back to SF Symbol
        if let imageName = goal.imageName,
           let img = UIImage(named: imageName) {
            GoalImage.image = img
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .thin)
            GoalImage.image = UIImage(systemName: goal.iconName, withConfiguration: config)?
                .withTintColor(AppColors.textSecondary, renderingMode: .alwaysOriginal)
            GoalImage.contentMode = .center
            GoalImage.backgroundColor = AppColors.sectionBackground
        }
    }

    // MARK: - IBActions

    @IBAction func addMoneyButtonTapped(_ sender: UIButton) {
        onAddMoney?()
    }
    

    @IBAction func goalEditButtonTapped(_ sender: UIButton) {
        onDetail?()
    }
    

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double) -> String {
        let f             = NumberFormatter()
        f.numberStyle     = .currency
        f.currencyCode    = "INR"
        f.currencySymbol  = "₹"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "₹0"
    }

    private func formattedMonth(_ date: Date) -> String {
        let f        = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: date)
    }
}
