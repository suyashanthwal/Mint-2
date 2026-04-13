
import UIKit

typealias TransactionCell = TransactionCellCollectionViewCell

class TransactionCellCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var IconBackgroundView: UIView!
    @IBOutlet weak var IconView: UIImageView!
    @IBOutlet weak var TransactionName: UILabel!
    @IBOutlet weak var TransactionDate: UILabel!
    @IBOutlet weak var TransactionAmount: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
    }

    func configure(with transaction: Transaction, category: Category?) {
        TransactionName.text      = transaction.name
        TransactionName.textColor = AppColors.textPrimary

        TransactionDate.text      = AppFormatters.transactionDate(transaction.timestamp)
        TransactionDate.textColor = AppColors.textSecondary

        TransactionAmount.text      = AppFormatters.transactionAmount(for: transaction)
        TransactionAmount.textColor = transaction.type == .income ? AppColors.brand : AppColors.error

        if let hexColor = category?.color {
            IconBackgroundView.backgroundColor = UIColor(hex: hexColor).withAlphaComponent(0.15)
        } else {
            IconBackgroundView.backgroundColor = AppColors.brandLight.withAlphaComponent(0.35)
        }

        let symbolName: String
        if let iconName = category?.icon, !iconName.isEmpty {
            symbolName = iconName
        } else {
            symbolName = transaction.type == .income ? "arrow.down.circle.fill" : "creditcard.fill"
        }

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        IconView.image       = UIImage(systemName: symbolName, withConfiguration: config)
        IconView.tintColor   = category.map { UIColor(hex: $0.color) } ?? AppColors.brand
        IconView.contentMode = .scaleAspectFit
    }

    private func setupAppearance() {
        contentView.backgroundColor      = AppColors.card
        contentView.layer.cornerRadius   = 0
        IconBackgroundView.clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        IconBackgroundView.layer.cornerRadius = IconBackgroundView.bounds.width / 2
    }
}
