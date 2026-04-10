//
//  ReceiptItemCell.swift
//  QrAndReceiptReading
//
//  Created by Ayush Singh Bhandari on 30/03/26.
//

import UIKit

class ReceiptItemCell: UICollectionViewCell {
      

        @IBOutlet weak var cardView: UIView!
        @IBOutlet weak var titleLabel: UILabel!
        @IBOutlet weak var priceLabel: UILabel!
        @IBOutlet weak var unitPriceLabel: UILabel!

        @IBOutlet weak var categoryPill: UIView!
        @IBOutlet weak var categoryIconImageView: UIImageView!
        @IBOutlet weak var categoryLabel: UILabel!
    
       // @IBOutlet weak var chevronImageView: UIImageView!

        var onCategoryTapped: (() -> Void)?

        override func awakeFromNib() {
            super.awakeFromNib()

            let tap = UITapGestureRecognizer(target: self, action: #selector(pillTapped))
            categoryPill.addGestureRecognizer(tap)
            categoryPill.isUserInteractionEnabled = true
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            cardView.layer.cornerRadius = 12
            categoryPill.layer.cornerRadius = categoryPill.bounds.height / 2
        }

        func configure(title: String,
                       price: String,
                       unitPrice: String?,
                       categoryName: String,
                       categoryIcon: UIImage?) {
            titleLabel.text = title
            priceLabel.text = price
            unitPriceLabel.text = unitPrice ?? ""

            categoryLabel.text = categoryName
            categoryIconImageView.image = categoryIcon
            //chevronImageView.image = UIImage(systemName: "chevron.down")
        }

        @objc private func pillTapped() {
            onCategoryTapped?()
        }

      
    }

