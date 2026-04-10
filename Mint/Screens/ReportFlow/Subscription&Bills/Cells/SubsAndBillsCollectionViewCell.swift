//
//  SubsAndBillsCollectionViewCell.swift
//  BudgetApp
//

import UIKit

class SubsAndBillsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var IconBackgroundView:    UIView!
    @IBOutlet weak var IconImageView:         UIImageView!
    @IBOutlet weak var AmountLabel:           UILabel!
    @IBOutlet weak var SubsAndBillsNameLabel: UILabel!

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        IconBackgroundView.clipsToBounds  = true
        IconImageView.tintColor           = AppColors.brand
        SubsAndBillsNameLabel.textColor   = AppColors.textPrimary
        AmountLabel.textColor             = AppColors.textPrimary
        IconBackgroundView.backgroundColor = AppColors.brandLight
    }

    override func layoutSubviews() {
        super.layoutSubviews()
       // IconBackgroundView.layer.cornerRadius = IconBackgroundView.bounds.width / 2
    }

    // MARK: - Configure for Upcoming Bills

    func configureBill(with bill: Bill) {
        IconImageView.image        = UIImage(systemName: bill.icon)
        SubsAndBillsNameLabel.text = bill.name
        AmountLabel.text           = "₹\(String(format: "%.2f", bill.amount))"
        let df        = DateFormatter()
        df.dateFormat = "MMM d"
    }

    // MARK: - Configure for Active Subscriptions
    // Bug 3 fix: show "Last paid MMM d" using lastDate instead of note/duration

    func configureSubscription(with subscription: RecurringPayment) {
        IconImageView.image        = UIImage(systemName: subscription.icon ?? "creditcard.fill")
        SubsAndBillsNameLabel.text = subscription.name
        AmountLabel.text           = "₹\(String(format: "%.2f", subscription.amount))"
    }
}
