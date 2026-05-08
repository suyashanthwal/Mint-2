
import UIKit

class SummaryCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.subviews
            .filter { !($0 is UILabel) }
            .forEach { $0.backgroundColor = AppColors.cardBorder.withAlphaComponent(0.55) }
    }

    func configure(title: String, amount: Double, isPositive: Bool) {
        titleLabel.text = title
        titleLabel.textColor = AppColors.textPrimary
        amountLabel.text = AppFormatters.currency(abs(amount))
        amountLabel.textColor = isPositive ? AppColors.brand : AppColors.error
    }
}
