
import UIKit

class IconCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var backgroundCircle: UIView!
        
        override func awakeFromNib() {
            super.awakeFromNib()
            setupCell()
        }
        
        private func setupCell() {
            backgroundCircle.backgroundColor = AppColors.brandLightText
            backgroundCircle.layer.cornerRadius = 25

            iconImageView.tintColor = AppColors.brand
            iconImageView.contentMode = .scaleAspectFit
        }
        
        func configure(with iconName: String) {
            iconImageView.image = UIImage(systemName: iconName)
        }
    }
