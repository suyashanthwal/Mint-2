
import UIKit

class IconHeaderCollectionReusableView: UICollectionReusableView {

        @IBOutlet weak var titleLabel: UILabel!

        override func awakeFromNib() {
            super.awakeFromNib()
            setupHeader()
        }
        
        private func setupHeader() {
            titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            titleLabel.textColor = .darkGray
        }
        
        func configure(with title: String) {
            titleLabel.text = title
        }
    }
