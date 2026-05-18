import UIKit

final class GoalsSectionHeaderReusableView: UICollectionReusableView {

    static let reuseIdentifier = "GoalsSectionHeaderReusableView"

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var countLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        titleLabel.numberOfLines = 1
        titleLabel.textColor = AppColors.textPrimary
        countLabel.textAlignment = .right
        countLabel.numberOfLines = 1
        countLabel.textColor = AppColors.textSecondary
    }

    func configure(title: String, countText: String) {
        titleLabel.text = title
        countLabel.text = countText
    }
}
