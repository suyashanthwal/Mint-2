
import UIKit

class ReceiptCaptureImageCell: UICollectionViewCell {

       

        @IBOutlet weak var receiptImageView: UIImageView!

        override func awakeFromNib() {
            super.awakeFromNib()
        }
        func configure(image: UIImage?) {
            receiptImageView.image = image
        }
    }

