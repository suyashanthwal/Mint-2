
import UIKit

class ReceiptSectionHeaderView: UICollectionReusableView {
       
        @IBOutlet private weak var sectionTitleLabel: UILabel!
        @IBOutlet private weak var itemCountPill: UIView!
        @IBOutlet private weak var itemCountLabel: UILabel!

      

        override func awakeFromNib() {
            super.awakeFromNib()
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            itemCountPill.layer.cornerRadius = itemCountPill.bounds.height / 2
            itemCountPill.clipsToBounds = true
        }
        func configure(title: String, itemCount: Int) {
            sectionTitleLabel.text = title
            itemCountLabel.text    = "\(itemCount) Items"
            itemCountPill.isHidden = itemCount == 0
        }
}
