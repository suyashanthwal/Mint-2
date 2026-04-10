//
//  SummaryCollectionViewCell.swift
//  BudgetApp
//

import UIKit

class SummaryCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func configure(title: String, amount: Double, isPositive: Bool) {
        titleLabel.text = title
        titleLabel.textColor = AppColors.textPrimary
        amountLabel.text = AppFormatters.currency(abs(amount))
        amountLabel.textColor = isPositive ? AppColors.brand : AppColors.error
    }
}
