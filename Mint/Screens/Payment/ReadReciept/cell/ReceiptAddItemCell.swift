
import UIKit

class ReceiptAddItemCell: UICollectionViewCell {

        static let reuseID = "ReceiptAddItemCell"

        @IBOutlet private weak var containerView: UIView!
        @IBOutlet private weak var plusIconImageView: UIImageView!
        @IBOutlet private weak var addItemLabel: UILabel!

        var onTap: (() -> Void)?

        override func awakeFromNib() {
            super.awakeFromNib()

            let tap = UITapGestureRecognizer(
                target: self,
                action: #selector(handleTap)
            )
            contentView.addGestureRecognizer(tap)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            
            addDashedBorder()
        }

        private func addDashedBorder() {
            containerView.layer.sublayers?
                .filter { $0.name == "dashedBorder" }
                .forEach { $0.removeFromSuperlayer() }

            let dash              = CAShapeLayer()
            dash.name             = "dashedBorder"
            dash.strokeColor      = UIColor.systemGray3.cgColor
            dash.fillColor        = UIColor.clear.cgColor
            dash.lineWidth        = 1.5
            dash.lineDashPattern  = [6, 4]
            dash.frame            = containerView.bounds
            dash.path             = UIBezierPath(
                roundedRect: containerView.bounds,
                cornerRadius: containerView.layer.cornerRadius
            ).cgPath
            containerView.layer.addSublayer(dash)
        }

        @objc private func handleTap() {
            
            UIView.animate(withDuration: 0.1) {
                self.containerView.alpha = 0.6
            } completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    self.containerView.alpha = 1.0
                }
            }
            onTap?()
        }
    }
   

