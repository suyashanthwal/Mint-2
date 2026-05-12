
import UIKit

class ReceiptCaptureImageCell: UICollectionViewCell {

       

        @IBOutlet weak var receiptImageView: UIImageView!

        override func awakeFromNib() {
            super.awakeFromNib()
            backgroundColor = .clear
            contentView.backgroundColor = .clear
            receiptImageView.backgroundColor = AppColors.card
            receiptImageView.layer.cornerRadius = 12
            receiptImageView.layer.borderWidth = 1
            receiptImageView.layer.borderColor = AppColors.cardBorder.withAlphaComponent(0.7).cgColor
            receiptImageView.clipsToBounds = true
        }
        func configure(image: UIImage?) {
            receiptImageView.image = image
        }
    }
