//
//  TransactionCellCollectionViewCell.swift
//  RecentTransactions
//
//  Created by Suyash Anthwal on 08/04/26.
//

import UIKit

// MARK: - Type alias so the VC can refer to the cell as "TransactionCell"
typealias TransactionCell = TransactionCellCollectionViewCell

class TransactionCellCollectionViewCell: UICollectionViewCell {

    // MARK: - Outlets

    @IBOutlet weak var IconBackgroundView: UIView!
    @IBOutlet weak var IconView: UIImageView!
    @IBOutlet weak var TransactionName: UILabel!
    @IBOutlet weak var TransactionDate: UILabel!
    @IBOutlet weak var TransactionAmount: UILabel!

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        setupAppearance()
    }

    // MARK: - Configuration

    /// Populates every visible element of the cell from a `Transaction` and its optional `Category`.
    func configure(with transaction: Transaction, category: Category?) {
        // ── Name ─────────────────────────────────────────────────────────────
        TransactionName.text      = transaction.name
        TransactionName.textColor = AppColors.textPrimary

        // ── Date ─────────────────────────────────────────────────────────────
        TransactionDate.text      = AppFormatters.transactionDate(transaction.timestamp)
        TransactionDate.textColor = AppColors.textSecondary

        // ── Amount ───────────────────────────────────────────────────────────
        TransactionAmount.text      = AppFormatters.transactionAmount(for: transaction)
        TransactionAmount.textColor = transaction.type == .income ? AppColors.brand : AppColors.error

        // ── Icon background ──────────────────────────────────────────────────
        if let hexColor = category?.color {
            IconBackgroundView.backgroundColor = UIColor(hex: hexColor).withAlphaComponent(0.15)
        } else {
            IconBackgroundView.backgroundColor = AppColors.brandLight.withAlphaComponent(0.35)
        }

        // ── SF Symbol icon ───────────────────────────────────────────────────
        let symbolName: String
        if let iconName = category?.icon, !iconName.isEmpty {
            symbolName = iconName
        } else {
            symbolName = transaction.type == .income ? "arrow.down.circle.fill" : "creditcard.fill"
        }

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        IconView.image       = UIImage(systemName: symbolName, withConfiguration: config)
        IconView.tintColor   = category.map { UIColor(hex: $0.color) } ?? AppColors.brand
        IconView.contentMode = .scaleAspectFit
    }

    // MARK: - Private helpers

    private func setupAppearance() {
        contentView.backgroundColor      = AppColors.card
        contentView.layer.cornerRadius   = 0
        IconBackgroundView.clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        IconBackgroundView.layer.cornerRadius = IconBackgroundView.bounds.width / 2
    }
}
