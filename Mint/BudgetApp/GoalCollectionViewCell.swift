import UIKit

struct BudgetGoalItem {
    let title: String
    let amount: String
    let symbolName: String
}

final class GoalCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "GoalCollectionViewCell"

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        cardView.backgroundColor = AppColors.card
        cardView.layer.cornerRadius = 8
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = AppColors.cardBorder.cgColor
        iconImageView.tintColor = AppColors.brandText
        titleLabel.textColor = AppColors.textPrimary
        amountLabel.textColor = AppColors.textPrimary
        titleLabel.font = MintFont.space(size: 14, weight: .semibold)
        amountLabel.font = MintFont.space(size: 14, weight: .semibold)
    }

    func configure(with item: BudgetGoalItem) {
        iconImageView.image = UIImage(systemName: item.symbolName)
        titleLabel.text = item.title
        amountLabel.text = item.amount
        titleLabel.removeCharacterSpacing()
        amountLabel.removeCharacterSpacing()
    }
}
