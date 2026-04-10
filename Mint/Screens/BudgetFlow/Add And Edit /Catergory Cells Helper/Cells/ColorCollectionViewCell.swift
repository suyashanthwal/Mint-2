//
//  ColorCollectionViewCell.swift
//  EditPages
//
//  Created by Anushk Barmola on 13/02/26.
//

import UIKit

class ColorCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var selectionRing: UIView!
        
    let cornerRadius: CGFloat = 25
        
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCell()
    }
        
    private func setupCell() {
        selectionRing?.layer.borderWidth = 2
        selectionRing?.layer.borderColor = UIColor.clear.cgColor
        selectionRing?.layer.cornerRadius = cornerRadius
        colorView?.layer.cornerRadius = cornerRadius
    }
        
    func configure(with color: UIColor, isSelected: Bool) {
        colorView?.backgroundColor = color
        colorView?.layer.cornerRadius = cornerRadius
        selectionRing?.layer.borderWidth = 2
        selectionRing?.layer.borderColor = isSelected ? color.cgColor : UIColor.clear.cgColor
        selectionRing?.layer.cornerRadius = cornerRadius
    }
}
