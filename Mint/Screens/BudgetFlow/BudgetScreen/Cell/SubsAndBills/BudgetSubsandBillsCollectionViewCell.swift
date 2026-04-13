
import UIKit

class BudgetSubsandBillsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var SubsandBillsIconView: UIView!
    @IBOutlet weak var SubsandBillsIcon: UIImageView!
    @IBOutlet weak var SubsandBillsTitle: UILabel!
    @IBOutlet weak var SubsandBillsPrice: UILabel!
    @IBOutlet weak var PillView: UIView!
    @IBOutlet weak var PillIcon: UIImageView!
    @IBOutlet weak var PillStatus: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.backgroundColor     = AppColors.card
        contentView.layer.cornerRadius  = 16
        contentView.layer.masksToBounds = true
        SubsandBillsIconView.layer.cornerRadius = 10
    }

    func configure(RecurringPayment payment: RecurringPayment) {
        SubsandBillsTitle.text      = payment.name
        SubsandBillsTitle.textColor = AppColors.textPrimary

        SubsandBillsPrice.text      = currencyFormatter.string(from: NSNumber(value: payment.amount)) ?? "₹0"
        SubsandBillsPrice.textColor = AppColors.textPrimary

        let iconName = payment.icon ?? "arrow.triangle.2.circlepath"
        SubsandBillsIcon.image    = UIImage(systemName: iconName)?.withRenderingMode(.alwaysTemplate)
        SubsandBillsIcon.tintColor = AppColors.brand

        SubsandBillsIconView.backgroundColor = AppColors.brandLight

        PillView.isHidden = false
        PillView.layer.cornerRadius  = 8
        PillView.layer.masksToBounds = true

        if payment.isActive {
            PillIcon.image           = UIImage(systemName: "checkmark.circle.fill")
            PillIcon.tintColor       = AppColors.brand
            PillStatus.text          = "Active"
            PillStatus.textColor     = AppColors.brand
            PillView.backgroundColor = AppColors.brandLight.withAlphaComponent(0.4)
        } else {
            PillIcon.image           = UIImage(systemName: "pause.circle.fill")
            PillIcon.tintColor       = AppColors.textSecondary
            PillStatus.text          = "Paused"
            PillStatus.textColor     = AppColors.textSecondary
            PillView.backgroundColor = AppColors.sectionBackground
        }
    }

    func configureBill(bill: Bill) {
        SubsandBillsTitle.text      = bill.name
        SubsandBillsTitle.textColor = AppColors.textPrimary

        SubsandBillsPrice.text      = currencyFormatter.string(from: NSNumber(value: bill.amount)) ?? "₹0"
        SubsandBillsPrice.textColor = AppColors.textPrimary

        SubsandBillsIcon.image     = UIImage(systemName: bill.icon)?.withRenderingMode(.alwaysTemplate)
        SubsandBillsIcon.tintColor = AppColors.textSecondary

        SubsandBillsIconView.backgroundColor = AppColors.brandLight

        PillView.isHidden = false
        PillView.layer.cornerRadius  = 8
        PillView.layer.masksToBounds = true

        configurePill(for: bill)
    }

    private func configurePill(for bill: Bill) {
        if bill.isPaid {
            PillIcon.image           = UIImage(systemName: "checkmark.circle.fill")
            PillIcon.tintColor       = AppColors.brand
            PillStatus.text          = "Paid"
            PillStatus.textColor     = AppColors.brand
            PillView.backgroundColor = AppColors.brandLight.withAlphaComponent(0.4)

        } else if bill.billDate < Calendar.current.startOfDay(for: Date()) {
            PillIcon.image           = UIImage(systemName: "exclamationmark.triangle.fill")
            PillIcon.tintColor       = AppColors.error
            PillStatus.text          = "Overdue"
            PillStatus.textColor     = AppColors.error
            PillView.backgroundColor = AppColors.errorBackground

        } else {
            PillIcon.image           = UIImage(systemName: "info.circle.fill")
            PillIcon.tintColor       = UIColor(hex: "#A07800")
            PillStatus.text          = "Due"
            PillStatus.textColor     = UIColor(hex: "#A07800")
            PillView.backgroundColor = UIColor(hex: "#FFF3CC")
        }
    }
}
