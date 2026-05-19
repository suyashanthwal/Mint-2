
import UIKit

final class ReceiptHeaderCell: UICollectionViewCell {
   

    @IBOutlet private weak var iconCircleView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var merchantLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!
    @IBOutlet private weak var amountPill: UIView!
    @IBOutlet private weak var amountLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        merchantLabel.font = MintFont.space(size: 22, weight: .bold)
        merchantLabel.textColor = AppColors.textPrimary
        merchantLabel.textAlignment = .center
        merchantLabel.numberOfLines = 1

        dateLabel.font = MintFont.space(size: 13, weight: .medium)
        dateLabel.textColor = AppColors.textSecondary
        dateLabel.textAlignment = .center

        amountLabel.font = MintFont.space(size: 18, weight: .bold)
        amountLabel.textAlignment = .center

        iconImageView.contentMode = .scaleAspectFit
        iconCircleView.backgroundColor = AppColors.sectionBackground
        amountPill.backgroundColor = AppColors.brandLight
        amountLabel.textColor = AppColors.brandLightText
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        iconCircleView.clipsToBounds = true
        amountPill.clipsToBounds = true
        iconCircleView.layer.cornerRadius = iconCircleView.bounds.height / 2
        amountPill.layer.cornerRadius = amountPill.bounds.height / 2
    }

    func configure(merchant: String?, dateText: String?, totalText: String?, icon: UIImage? = nil) {
        let merchantText = (merchant?.isEmpty == false) ? merchant : "Unknown Merchant"
        merchantLabel.text = merchantText
        dateLabel.text = dateText ?? ""
        amountLabel.text = totalText ?? ""
        iconImageView.image = icon ?? UIImage(systemName: "doc.text")
        iconImageView.tintColor = AppColors.brand
    }
}
