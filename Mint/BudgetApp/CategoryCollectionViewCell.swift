import UIKit

struct BudgetCategoryItem {
    let title: String
    let amount: String
    let symbolName: String
    let progress: Float
    let accentColor: UIColor
    let backgroundColor: UIColor
    let iconColor: UIColor
}

final class CategoryCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "CategoryCollectionViewCell"

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var iconContainerView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var progressTrackView: UIView!
    @IBOutlet private weak var progressFillView: UIView!
    @IBOutlet private weak var progressFillWidthConstraint: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        iconContainerView.layer.cornerRadius = iconContainerView.bounds.height / 2
        progressTrackView.layer.cornerRadius = progressTrackView.bounds.height / 2
        progressFillView.layer.cornerRadius = progressFillView.bounds.height / 2
    }

    private func setupUI() {
        contentView.backgroundColor = .clear
        cardView.layer.cornerRadius = 18
        cardView.layer.borderWidth = 2
        cardView.clipsToBounds = true
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.82
        amountLabel.textColor = AppColors.textPrimary
        amountLabel.font = .systemFont(ofSize: 18, weight: .bold)
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.76
        iconImageView.tintColor = AppColors.brandText
        iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
        progressTrackView.clipsToBounds = true
        progressFillView.clipsToBounds = true
    }

    func configure(with item: BudgetCategoryItem) {
        cardView.backgroundColor = item.backgroundColor
        cardView.layer.borderColor = item.accentColor.cgColor
        iconContainerView.backgroundColor = item.iconColor
        iconImageView.image = UIImage(systemName: item.symbolName)?.withRenderingMode(.alwaysTemplate)
        iconImageView.tintColor = AppColors.brandText
        progressFillWidthConstraint.isActive = false
        progressFillWidthConstraint = progressFillView.widthAnchor.constraint(equalTo: progressTrackView.widthAnchor, multiplier: CGFloat(item.progress))
        progressFillWidthConstraint.isActive = true
        progressFillView.backgroundColor = item.accentColor
        progressTrackView.backgroundColor = item.accentColor.withAlphaComponent(0.32)
        titleLabel.text = item.title
        amountLabel.text = item.amount
    }
}
