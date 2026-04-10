//
//  TPCCollectionViewCell.swift
//  BudgetApp
//

import UIKit

class TPCCollectionViewCell: UICollectionViewCell {

    // MARK: - Outlets
    @IBOutlet weak var CategoryIconView: UIView!
    @IBOutlet weak var categoryIcon: UIImageView!
    @IBOutlet weak var CategoryName: UILabel!
    @IBOutlet weak var categoryTransactionsNumber: UILabel!
    @IBOutlet weak var categoryAmount: UILabel!
    @IBOutlet weak var categoryPercent: UILabel!

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        categoryIcon.layer.cornerRadius = 8
        categoryIcon.clipsToBounds      = true
    }

    // MARK: - Summary mode — one row per category (full pie visible)

    func configure(with category: Category,
                   total: Double,
                   transactionCount: Int,
                   totalExpense: Double) {

        // Labels
        CategoryName.text               = category.name
        CategoryName.textColor          = AppColors.textPrimary

        categoryAmount.text             = AppFormatters.currency(total)
        categoryAmount.textColor        = AppColors.textPrimary

        categoryTransactionsNumber.text  = "\(transactionCount) transaction\(transactionCount == 1 ? "" : "s")"
        categoryTransactionsNumber.textColor = AppColors.textSecondary

        let percent                      = totalExpense > 0 ? (total / totalExpense) * 100 : 0
        categoryPercent.text             = String(format: "%.1f%%", percent)
        categoryPercent.textColor        = AppColors.textSecondary
        categoryPercent.isHidden         = false

        // Icon
        applyIcon(systemName: category.icon,
                  tintColor: UIColor(hex: category.color) ?? AppColors.brand)
    }

    // MARK: - Detail mode — one row per transaction (category slice tapped)

    func configure(with transaction: Transaction, category: Category) {

        // Transaction name replaces category name
        CategoryName.text               = transaction.name
        CategoryName.textColor          = AppColors.textPrimary

        // Amount
        categoryAmount.text             = AppFormatters.currency(transaction.amount)
        categoryAmount.textColor        = AppColors.textPrimary

        // Date goes where transaction count was
        categoryTransactionsNumber.text  = AppFormatters.shortDate.string(from: transaction.timestamp)
        categoryTransactionsNumber.textColor = AppColors.textSecondary

        // Percent is irrelevant for individual transactions — hide it
        categoryPercent.isHidden         = true

        // Icon uses the category's SF Symbol + color (same category for every row in this drill-down)
        applyIcon(systemName: category.icon,
                  tintColor: UIColor(hex: category.color) ?? AppColors.brand)
    }

    // MARK: - Shared icon helper

    private func applyIcon(systemName: String, tintColor: UIColor) {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        categoryIcon.image           = UIImage(systemName: systemName, withConfiguration: config)
        categoryIcon.tintColor       = tintColor
        categoryIcon.backgroundColor = tintColor.withAlphaComponent(0.15)
        // Keep the wrapping view consistent too
        CategoryIconView.backgroundColor = tintColor.withAlphaComponent(0.15)
        CategoryIconView.layer.cornerRadius = 10
        CategoryIconView.clipsToBounds      = true
    }
}
