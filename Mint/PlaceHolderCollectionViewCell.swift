//
//  PlaceHolderCollectionViewCell.swift
//  Mint
//
//  Created by Anushk Barmola on 24/04/26.
//

import UIKit

final class PlaceHolderCollectionViewCell: UICollectionViewCell {

    enum SizeStyle {
        case fill
        case compact
        case listRow
    }

    static let reuseIdentifier = "PlaceHolderCollectionViewCell"
    static let nibName = "PlaceHolderCollectionViewCell"

    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var infoLabel: UILabel!
    @IBOutlet private weak var containerTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var containerLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var containerBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var containerTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var containerWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var containerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var infoLabelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var infoLabelTrailingConstraint: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.backgroundColor = .clear
        containerView.backgroundColor = AppColors.card
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true

        infoLabel.textColor = AppColors.textSecondary
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 0
        infoLabel.font = MintFont.space(size: UIFont.preferredFont(forTextStyle: .footnote).pointSize)

        apply(sizeStyle: .fill)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        infoLabel.text = nil
        apply(sizeStyle: .fill)
    }

    func configure(message: String, sizeStyle: SizeStyle = .fill) {
        infoLabel.text = message
        isUserInteractionEnabled = false
        apply(sizeStyle: sizeStyle)
    }

    private func apply(sizeStyle: SizeStyle) {
        switch sizeStyle {
        case .fill:
            containerView.layer.cornerRadius = 16
            containerTopConstraint.priority = .required
            containerLeadingConstraint.priority = .required
            containerBottomConstraint.priority = .required
            containerTrailingConstraint.priority = .required
            containerTopConstraint.constant = 0
            containerLeadingConstraint.constant = 0
            containerBottomConstraint.constant = 0
            containerTrailingConstraint.constant = 0
            containerWidthConstraint.priority = .defaultLow
            containerHeightConstraint.priority = .defaultLow
            infoLabelLeadingConstraint.constant = 12
            infoLabelTrailingConstraint.constant = 12

        case .compact:
            containerView.layer.cornerRadius = 16
            containerTopConstraint.priority = .defaultLow
            containerLeadingConstraint.priority = .required
            containerBottomConstraint.priority = .defaultLow
            containerTrailingConstraint.priority = .required
            containerTopConstraint.constant = 0
            containerLeadingConstraint.constant = 0
            containerBottomConstraint.constant = 0
            containerTrailingConstraint.constant = 0
            containerWidthConstraint.priority = .defaultLow
            containerHeightConstraint.priority = .required
            infoLabelLeadingConstraint.constant = 12
            infoLabelTrailingConstraint.constant = 12

        case .listRow:
            containerView.layer.cornerRadius = 0
            containerTopConstraint.priority = .required
            containerLeadingConstraint.priority = .required
            containerBottomConstraint.priority = .required
            containerTrailingConstraint.priority = .required
            containerTopConstraint.constant = 0
            containerLeadingConstraint.constant = 0
            containerBottomConstraint.constant = 0
            containerTrailingConstraint.constant = 0
            containerWidthConstraint.priority = .defaultLow
            containerHeightConstraint.priority = .defaultLow
            infoLabelLeadingConstraint.constant = 20
            infoLabelTrailingConstraint.constant = 20
        }
    }

}
