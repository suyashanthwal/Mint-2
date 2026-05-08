
import UIKit

class SubsAndBillsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var IconBackgroundView:    UIView!
    @IBOutlet weak var IconImageView:         UIImageView!
    @IBOutlet weak var AmountLabel:           UILabel!
    @IBOutlet weak var SubsAndBillsNameLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        IconBackgroundView.clipsToBounds  = true
        IconImageView.tintColor           = AppColors.brand
        SubsAndBillsNameLabel.textColor   = AppColors.textPrimary
        AmountLabel.textColor             = AppColors.textPrimary
        IconBackgroundView.backgroundColor = AppColors.brandLight
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    func configureBill(with bill: Bill) {
        IconImageView.image        = UIImage(systemName: bill.icon)
        SubsAndBillsNameLabel.text = bill.name
        AmountLabel.text           = "₹\(String(format: "%.2f", bill.amount))"
        let df        = DateFormatter()
        df.dateFormat = "MMM d"
    }

    func configureSubscription(with subscription: RecurringPayment) {
        IconImageView.image        = UIImage(systemName: subscription.icon ?? "creditcard.fill")
        SubsAndBillsNameLabel.text = subscription.name
        AmountLabel.text           = "₹\(String(format: "%.2f", subscription.amount))"
    }
}
