import UIKit

class MonthStripCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var MonthBackgroundView: UIView!
    @IBOutlet weak var MonthLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        MonthBackgroundView.layer.cornerRadius = 16
        MonthBackgroundView.clipsToBounds = true
    }

    func configure(month: String, year: Int, isSelected: Bool) {
        MonthLabel.text = "\(month) \(year)"
        MonthLabel.font = MintFont.space(size: 13, weight: isSelected ? .semibold : .regular)
        MonthLabel.textColor = isSelected ? AppColors.brandText : AppColors.textSecondary
        MonthBackgroundView.backgroundColor = isSelected
            ? AppColors.brand
            : AppColors.sectionBackground
    }
}
