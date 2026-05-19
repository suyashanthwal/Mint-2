
import UIKit

class SubsCalenderCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var dotView: UIView!
    @IBOutlet weak var dateLabel:      UILabel!
    @IBOutlet weak var backgroundPill: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        backgroundPill?.layer.cornerRadius = 10
        backgroundPill?.clipsToBounds      = true
        backgroundPill?.backgroundColor    = .clear

    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dotView.layer.cornerRadius = 2.5
        dotView.clipsToBounds      = true
    }

    func configure(day: Int?,
                   isToday: Bool = false,
                   isSelected: Bool = false,
                   isPadding: Bool = false,
                   hasBill: Bool = false,
                   todayColor: UIColor = AppColors.brandLight,
                   highlightColor: UIColor = AppColors.brand,
                   highlightTextColor: UIColor = AppColors.brandText) {

        guard let day = day else {
            dateLabel.text         = ""
            dotView.isHidden       = true
            backgroundPill.backgroundColor = .clear
            return
        }

        dateLabel.text   = "\(day)"
        dateLabel.textColor = AppColors.textPrimary
        dotView.isHidden = !hasBill

        if isSelected {
            backgroundPill.backgroundColor = highlightColor
            dateLabel.textColor            = highlightTextColor
            dateLabel.font                 = MintFont.space(size: 16, weight: .bold)
            dotView.backgroundColor        = highlightTextColor

        } else if isToday {
            backgroundPill.backgroundColor = todayColor
            dateLabel.textColor            = AppColors.brandLightText
            dateLabel.font                 = MintFont.space(size: 16, weight: .semibold)
            dotView.backgroundColor        = AppColors.brand

        } else if isPadding {
            backgroundPill.backgroundColor = .clear
            dateLabel.textColor = AppColors.textSecondary.withAlphaComponent(0.35)
            dateLabel.font      = MintFont.space(size: 16, weight: .regular)
            dotView.backgroundColor = AppColors.brand

        } else {
            backgroundPill.backgroundColor = .clear
            dateLabel.textColor = AppColors.textPrimary
            dateLabel.font      = MintFont.space(size: 16, weight: .medium)
            dotView.backgroundColor = AppColors.brand
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        dateLabel.text                 = ""
        dotView.isHidden               = true
        backgroundPill.backgroundColor = .clear
        dateLabel.textColor            = AppColors.textPrimary
        dateLabel.font                 = MintFont.space(size: 16, weight: .medium)
    }
}
