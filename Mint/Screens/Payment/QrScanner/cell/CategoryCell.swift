//
//  CategoryCell.swift
//  QrAndReceiptReading
//
//  Created by Ayush Singh Bhandari on 06/04/26.
//

import UIKit

class CategoryCell: UICollectionViewCell {
        
        static let reuseID = "CategoryCell"

        @IBOutlet weak var cardView: UIView!
        @IBOutlet weak var iconImageView: UIImageView!
        @IBOutlet weak var nameLabel: UILabel!

        override func awakeFromNib() {
            super.awakeFromNib()
            cardView.layer.cornerRadius = 14
            cardView.clipsToBounds = true
            iconImageView.contentMode = .scaleAspectFit
            nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
            nameLabel.textAlignment = .center
        }

        func configure(with category: Category, isSelected: Bool) {
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            iconImageView.image = UIImage(systemName: category.icon,
                                          withConfiguration: config)
            nameLabel.text = category.name

            let categoryColor = UIColor(hex: category.color)

            if isSelected {
                cardView.backgroundColor = categoryColor.withAlphaComponent(0.18)
                iconImageView.tintColor  = categoryColor
                nameLabel.textColor      = categoryColor
            } else {
                cardView.backgroundColor = AppColors.sectionBackground
                iconImageView.tintColor  = AppColors.textSecondary
                nameLabel.textColor      = AppColors.textSecondary
            }
        }
}

