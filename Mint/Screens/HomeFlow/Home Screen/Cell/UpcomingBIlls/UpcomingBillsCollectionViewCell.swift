//
//  BudgetCollectionViewCell.swift
//  BudgetApp
//
//  Created by Suyash Anthwal on 19/02/26.
//

import UIKit

class UpcomingBillsCollectionViewCell: UICollectionViewCell {

    // MARK: - Outlets
    @IBOutlet weak var Title: UILabel!
    @IBOutlet weak var Amount: UILabel!
    @IBOutlet weak var duration: UILabel!
    @IBOutlet weak var leftAccentBar: UIView!

    private let urgentThreshold = 3

    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()

        // ✅ Apply card shadow + cornerRadius 12 from styling.swift
        self.applyShadow()

        // ✅ Clip contentView so background stays inside rounded corners
        contentView.layer.cornerRadius  = 12
        contentView.layer.masksToBounds = true
        contentView.backgroundColor     = AppColors.card
        Title.textColor                 = AppColors.textPrimary
        Amount.textColor                = AppColors.textPrimary
        duration.textColor              = AppColors.textSecondary

        // ✅ Round only the left corners of the accent bar to match the card edge
        leftAccentBar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        leftAccentBar.layer.masksToBounds = true
    }

    // MARK: - Configuration
    func configureCell(with bill: Bill) {
        if bill.isPaid {
            duration.text = "PAID"
            leftAccentBar.backgroundColor = AppColors.brand
            duration.textColor = AppColors.brand
            Title.text = bill.name
            Amount.text = bill.amount.formatted(.currency(code: "INR"))
            contentView.alpha = 0.7
            return
        }

        contentView.alpha = 1.0

        // --- Days until due ---
        let today        = Calendar.current.startOfDay(for: Date())
        let billDay      = Calendar.current.startOfDay(for: bill.billDate)
        let daysUntilDue = Calendar.current.dateComponents([.day], from: today, to: billDay).day ?? 0

        // --- "IN X DAYS" label ---
        switch daysUntilDue {
        case ..<0:
            duration.text = "OVERDUE"
        case 0:
            duration.text = "DUE TODAY"
        case 1:
            duration.text = "IN 1 DAY"
        default:
            duration.text = "IN \(daysUntilDue) DAYS"
        }

        // --- Accent color: red if urgent (≤3 days), green otherwise ---
        let accentColor: UIColor = daysUntilDue <= urgentThreshold ? AppColors.error : AppColors.brand
        leftAccentBar.backgroundColor = accentColor
        duration.textColor            = accentColor

        // --- Bill name & amount ---
        Title.text  = bill.name
        Amount.text = bill.amount.formatted(.currency(code: "INR"))
    }
}
