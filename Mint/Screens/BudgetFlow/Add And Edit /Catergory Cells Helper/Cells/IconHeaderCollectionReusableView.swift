
import UIKit

class IconHeaderCollectionReusableView: UICollectionReusableView {

        @IBOutlet weak var titleLabel: UILabel!

        override func awakeFromNib() {
            super.awakeFromNib()
            setupHeader()
        }
        
        private func setupHeader() {
            titleLabel.font = MintFont.space(size: 14, weight: .semibold)
            titleLabel.textColor = AppColors.textPrimary
        }
        
        func configure(with title: String) {
            titleLabel.text = title
        }
    }
