
import UIKit

class CategoryCell: UICollectionViewCell {
        
        static let reuseID = "CategoryCell"

        @IBOutlet weak var cardView: UIView!
        @IBOutlet weak var iconImageView: UIImageView!
        @IBOutlet weak var nameLabel: UILabel!

        override func awakeFromNib() {
            super.awakeFromNib()
            backgroundColor = .clear
            contentView.backgroundColor = .clear
            cardView.layer.cornerRadius = 14
            cardView.clipsToBounds = true
            cardView.layer.borderWidth = 1
            iconImageView.contentMode = .scaleAspectFit
            nameLabel.font = MintFont.space(size: 11, weight: .medium)
            nameLabel.textAlignment = .center
        }

        func configure(with category: Category, isSelected: Bool) {
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            iconImageView.image = UIImage(systemName: category.icon,
                                          withConfiguration: config)
            nameLabel.text = category.name

            let categoryColor = UIColor(hex: category.color)

            if isSelected {
                cardView.backgroundColor = AppColors.brandLight
                cardView.layer.borderColor = AppColors.brand.cgColor
                iconImageView.tintColor  = AppColors.brand
                nameLabel.textColor      = AppColors.textPrimary
            } else {
                cardView.backgroundColor = AppColors.inputBackground
                cardView.layer.borderColor = AppColors.cardBorder.withAlphaComponent(0.7).cgColor
                iconImageView.tintColor  = AppColors.textSecondary
                nameLabel.textColor      = AppColors.textSecondary
            }
        }
}
