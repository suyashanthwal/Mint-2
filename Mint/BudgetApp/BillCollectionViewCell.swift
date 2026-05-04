import UIKit

struct BudgetBillItem {
    let title: String
    let amount: String
    let date: String
    let symbolName: String
    let dotColor: UIColor
}

final class BillCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "BillCollectionViewCell"

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        cardView.backgroundColor = AppColors.card
        cardView.layer.cornerRadius = 8
        iconImageView.tintColor = AppColors.brandText
        titleLabel.textColor = AppColors.textPrimary
        amountLabel.textColor = AppColors.textPrimary
        dateLabel.textColor = AppColors.textSecondary
    }

    func configure(with item: BudgetBillItem) {
        iconImageView.image = UIImage(systemName: item.symbolName)
        titleLabel.text = item.title
        amountLabel.text = item.amount
        dateLabel.text = item.date
    }
}
