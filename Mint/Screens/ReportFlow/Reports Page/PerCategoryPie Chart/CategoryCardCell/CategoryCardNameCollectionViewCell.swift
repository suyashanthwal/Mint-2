//
//  CategoryCardNameCollectionViewCell.swift
//  Mint
//
//  Created by Suyash Anthwal on 23/04/26.
//

import UIKit

class CategoryCardNameCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var CategoryView: UIView!
    @IBOutlet weak var CategoryNameLabel: UILabel!
    @IBOutlet weak var CategoryPercentLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        CategoryView.layer.cornerRadius = 8
        CategoryView.layer.masksToBounds = true
    }

    func configure(with category: CategorySpending) {
        setRow(
            dot: CategoryView,
            name: CategoryNameLabel,
            percent: CategoryPercentLabel,
            cat: category
        )
    }

    private func setRow(dot: UIView?, name: UILabel?, percent: UILabel?, cat: CategorySpending?) {
        guard let cat = cat else {
            dot?.superview?.isHidden = true
            return
        }
        dot?.superview?.isHidden = false
        dot?.backgroundColor = cat.color
        name?.text           = cat.name
        name?.textColor      = cat.color
        percent?.text        = "\(cat.percent)%"
        percent?.textColor   = AppColors.textSecondary
    }
}
