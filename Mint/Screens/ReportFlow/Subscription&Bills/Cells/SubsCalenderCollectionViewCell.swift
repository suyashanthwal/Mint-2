
import UIKit

class SubsCalenderCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var eventIconImageView: UIImageView!
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
    }

    func configure(day: Int?,
                   isToday: Bool = false,
                   isSelected: Bool = false,
                   isPadding: Bool = false,
                   eventIconName: String? = nil,
                   todayColor: UIColor = AppColors.brandLight,
                   highlightColor: UIColor = AppColors.brand,
                   highlightTextColor: UIColor = AppColors.brandText) {

        guard let day = day else {
            dateLabel.text = ""
            dateLabel.isHidden = false
            eventIconImageView.image = nil
            eventIconImageView.isHidden = true
            backgroundPill.backgroundColor = .clear
            return
        }

        let hasEventIcon = !(eventIconName?.isEmpty ?? true)
        dateLabel.text = "\(day)"
        dateLabel.isHidden = hasEventIcon
        dateLabel.textColor = AppColors.textPrimary
        eventIconImageView.isHidden = !hasEventIcon
        eventIconImageView.image = hasEventIcon
            ? (UIImage(systemName: eventIconName ?? "calendar") ?? UIImage(systemName: "calendar"))
            : nil

        if isSelected {
            backgroundPill.backgroundColor = highlightColor
            dateLabel.textColor            = highlightTextColor
            dateLabel.font                 = MintFont.space(size: 16, weight: .bold)
            eventIconImageView.tintColor   = highlightTextColor

        } else if isToday {
            backgroundPill.backgroundColor = todayColor
            dateLabel.textColor            = AppColors.brandLightText
            dateLabel.font                 = MintFont.space(size: 16, weight: .semibold)
            eventIconImageView.tintColor   = AppColors.brandLightText

        } else if isPadding {
            backgroundPill.backgroundColor = .clear
            dateLabel.textColor = AppColors.textSecondary.withAlphaComponent(0.35)
            dateLabel.font      = MintFont.space(size: 16, weight: .regular)
            eventIconImageView.tintColor = AppColors.textSecondary.withAlphaComponent(0.35)

        } else {
            backgroundPill.backgroundColor = .clear
            dateLabel.textColor = AppColors.textPrimary
            dateLabel.font      = MintFont.space(size: 16, weight: .medium)
            eventIconImageView.tintColor = AppColors.brand
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        dateLabel.text                 = ""
        dateLabel.isHidden             = false
        eventIconImageView.image       = nil
        eventIconImageView.isHidden    = true
        backgroundPill.backgroundColor = .clear
        dateLabel.textColor            = AppColors.textPrimary
        dateLabel.font                 = MintFont.space(size: 16, weight: .medium)
        eventIconImageView.tintColor   = AppColors.brand
    }
}
