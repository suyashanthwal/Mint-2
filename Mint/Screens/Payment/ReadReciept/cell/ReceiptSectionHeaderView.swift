//
//  ReceiptSectionHeaderView.swift
//  QrAndReceiptReading
//
//  Created by Ayush Singh Bhandari on 01/04/26.
//

import UIKit

class ReceiptSectionHeaderView: UICollectionReusableView {
       
        @IBOutlet private weak var sectionTitleLabel: UILabel!
        @IBOutlet private weak var itemCountPill: UIView!
        @IBOutlet private weak var itemCountLabel: UILabel!

      

        override func awakeFromNib() {
            super.awakeFromNib()
            // Basic styling done in XIB
            // Only AppColors and frame-dependent stuff here
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
