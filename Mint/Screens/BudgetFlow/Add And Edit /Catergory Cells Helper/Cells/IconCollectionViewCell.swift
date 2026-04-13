
import UIKit

class IconCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var backgroundCircle: UIView!
        
        override func awakeFromNib() {
            super.awakeFromNib()
            setupCell()
        }
        
        private func setupCell() {
            backgroundCircle.backgroundColor = UIColor.systemGray5
            backgroundCircle.layer.cornerRadius = 25

            iconImageView.tintColor = .darkGray
            iconImageView.contentMode = .scaleAspectFit
        }
        
        func configure(with iconName: String) {
            iconImageView.image = UIImage(systemName: iconName)
        }
    }
