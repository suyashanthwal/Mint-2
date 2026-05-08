
import UIKit

class TPCCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var CategoryIconView: UIView!
    @IBOutlet weak var categoryIcon: UIImageView!
    @IBOutlet weak var CategoryName: UILabel!
    @IBOutlet weak var categoryTransactionsNumber: UILabel!
    @IBOutlet weak var categoryAmount: UILabel!
    @IBOutlet weak var categoryPercent: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        categoryIcon.layer.cornerRadius = 8
        categoryIcon.clipsToBounds      = true
    }

    func configure(with category: Category,
                   total: Double,
                   transactionCount: Int,
                   totalExpense: Double) {

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

        applyIcon(systemName: category.icon,
                  tintColor: UIColor(hex: category.color) ?? AppColors.brand)
    }

    func configure(with transaction: Transaction, category: Category) {

        CategoryName.text               = transaction.name
        CategoryName.textColor          = AppColors.textPrimary

        categoryAmount.text             = AppFormatters.currency(transaction.amount)
        categoryAmount.textColor        = AppColors.textPrimary

        categoryTransactionsNumber.text  = AppFormatters.shortDate.string(from: transaction.timestamp)
        categoryTransactionsNumber.textColor = AppColors.textSecondary

        categoryPercent.isHidden         = true

        applyIcon(systemName: category.icon,
                  tintColor: UIColor(hex: category.color) ?? AppColors.brand)
    }

    private func applyIcon(systemName: String, tintColor: UIColor) {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        categoryIcon.image           = UIImage(systemName: systemName, withConfiguration: config)
        categoryIcon.tintColor       = tintColor
        categoryIcon.backgroundColor = tintColor.withAlphaComponent(0.15)
        CategoryIconView.backgroundColor = tintColor.withAlphaComponent(0.15)
        CategoryIconView.layer.cornerRadius = 10
        CategoryIconView.clipsToBounds      = true
    }
}
