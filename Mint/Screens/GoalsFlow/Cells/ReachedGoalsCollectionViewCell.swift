//
//  ReachedGoalsCollectionViewCell.swift
//  BudgetApp
//
//  Created by Suyash Anthwal on 02/04/26.
//

import UIKit

class ReachedGoalsCollectionViewCell: UICollectionViewCell {
    // MARK: - Outlets

    @IBOutlet weak var IconBackgroundView: UIView!
    @IBOutlet weak var ReachedGoalName: UILabel!
    @IBOutlet weak var ReachedGoalCompletedOn: UILabel!
    @IBOutlet weak var ReachedGoalAmount: UILabel!

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        applyStyle()
    }

    // MARK: - Styling

    private func applyStyle() {
        contentView.backgroundColor = AppColors.card

        // Icon bubble — light brand green circle
        IconBackgroundView.backgroundColor    = AppColors.brandLight
        IconBackgroundView.layer.cornerRadius = IconBackgroundView.frame.width / 2
        IconBackgroundView.clipsToBounds      = true

        // Goal name
        ReachedGoalName.font      = UIFont.systemFont(ofSize: 15, weight: .semibold)
        ReachedGoalName.textColor = AppColors.textPrimary

        // Completed-on subtitle
        ReachedGoalCompletedOn.font      = UIFont.systemFont(ofSize: 12, weight: .regular)
        ReachedGoalCompletedOn.textColor = AppColors.textSecondary

        // Amount (right-aligned)
        ReachedGoalAmount.font      = UIFont.systemFont(ofSize: 15, weight: .bold)
        ReachedGoalAmount.textColor = AppColors.brand
        ReachedGoalAmount.textAlignment = .right
    }

    // MARK: - Configure

    func configure(with goal: Goal) {
        ReachedGoalName.text = goal.name

        if let completedOn = goal.completedOn {
            ReachedGoalCompletedOn.text = "Completed on \(formattedDate(completedOn))"
        } else {
            ReachedGoalCompletedOn.text = "Goal reached"
        }

        ReachedGoalAmount.text = formatCurrency(goal.targetAmount)

        // Icon inside the bubble — checkmark using SF Symbols
        // The icon is added programmatically so it works without a sub-outlet
        addIconIfNeeded(sfSymbol: goal.iconName)

        // Corner radius needs bounds — update after layout
        layoutIfNeeded()
        IconBackgroundView.layer.cornerRadius = IconBackgroundView.bounds.width / 2
    }

    // MARK: - Icon Helper

    private func addIconIfNeeded(sfSymbol: String) {
        // Remove any existing image views added programmatically
        IconBackgroundView.subviews
            .filter { $0.tag == 99 }
            .forEach { $0.removeFromSuperview() }

        let config    = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image     = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)?
            .withTintColor(AppColors.brand, renderingMode: .alwaysOriginal)

        let imageView        = UIImageView(image: image)
        imageView.tag        = 99
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        IconBackgroundView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: IconBackgroundView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: IconBackgroundView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),
        ])
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

    private func formattedDate(_ date: Date) -> String {
        let f        = DateFormatter()
        f.dateFormat = "MMM dd, yyyy"
        return f.string(from: date)
    }
}
