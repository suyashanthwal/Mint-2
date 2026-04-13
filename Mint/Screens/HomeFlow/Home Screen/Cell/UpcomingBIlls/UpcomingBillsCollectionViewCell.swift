
import UIKit

class UpcomingBillsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var Title: UILabel!
    @IBOutlet weak var Amount: UILabel!
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var leftAccentBar: UIView!

    private let urgentThreshold = 3

    override func awakeFromNib() {
        super.awakeFromNib()

        self.applyShadow()

        contentView.layer.cornerRadius  = 12
        contentView.layer.masksToBounds = true
        contentView.backgroundColor     = AppColors.card
        Title.textColor                 = AppColors.textPrimary
        Amount.textColor                = AppColors.textPrimary
        duration.textColor              = AppColors.textSecondary

        leftAccentBar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        leftAccentBar.layer.masksToBounds = true
    }

    func configureCell(with bill: Bill) {
        if bill.isPaid {
            duration.text = "PAID"
            leftAccentBar.backgroundColor = AppColors.brand
            duration.textColor = AppColors.brand
            Title.text = bill.name
            Amount.text = bill.amount.formatted(.currency(code: "INR"))
            contentView.alpha = 0.7
            return
        }

        contentView.alpha = 1.0

        let today        = Calendar.current.startOfDay(for: Date())
        let billDay      = Calendar.current.startOfDay(for: bill.billDate)
        let daysUntilDue = Calendar.current.dateComponents([.day], from: today, to: billDay).day ?? 0

        switch daysUntilDue {
        case ..<0:
            duration.text = "OVERDUE"
        case 0:
            duration.text = "DUE TODAY"
        case 1:
            duration.text = "IN 1 DAY"
        default:
            duration.text = "IN \(daysUntilDue) DAYS"
        }

        let accentColor: UIColor = daysUntilDue <= urgentThreshold ? AppColors.error : AppColors.brand
        leftAccentBar.backgroundColor = accentColor
        duration.textColor            = accentColor

        Title.text  = bill.name
        Amount.text = bill.amount.formatted(.currency(code: "INR"))
    }
}
