//
//  ReceiptCaptureImageCell.swift
//  QrAndReceiptReading
//
//  Created by Ayush Singh Bhandari on 01/04/26.
//

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


