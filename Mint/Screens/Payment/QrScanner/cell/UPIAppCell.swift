//
//  UPIAppCell.swift
//  QrAndReceiptReading
//
//  Created by Ayush Singh Bhandari on 07/04/26.
//

import UIKit

class UPIAppCell: UICollectionViewCell {

        static let reuseID = "UPIAppCell"

        @IBOutlet weak var iconImageView: UIImageView!
        @IBOutlet weak var nameLabel: UILabel!
        @IBOutlet weak var arrowImageView: UIImageView!

        override func awakeFromNib() {
            super.awakeFromNib()
        }

    func configure(name: String, isFirst: Bool) {
        nameLabel.text = name

        let branding: (asset: String, fallback: String, tint: UIColor) = {
            switch name {
            case "Google Pay":
                return ("google_pay", "wallet.pass.fill", .systemBlue)
            case "Paytm":
                return ("paytm", "banknote.fill", .systemBlue)
            case "PhonePe":
                return ("phonepe", "phone.circle.fill", .systemPurple)
            case "Bhim UPI":
                return ("bhim_upi", "building.columns.fill", .systemOrange)
            case "Amazon Pay":
                return ("amazon_pay", "cart.circle.fill", .systemGreen)
            default:
                return ("", "creditcard.circle.fill", .systemGray)
            }
        }()

        if let brandedImage = UIImage(named: branding.asset) {
            iconImageView.image = brandedImage
            iconImageView.tintColor = nil
        } else {
            iconImageView.image = UIImage(systemName: branding.fallback)
            iconImageView.tintColor = branding.tint
        }
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 10
        iconImageView.clipsToBounds = true
        
        contentView.backgroundColor = isFirst
            ? UIColor.systemBlue.withAlphaComponent(0.1)
            : .clear
    }
}
