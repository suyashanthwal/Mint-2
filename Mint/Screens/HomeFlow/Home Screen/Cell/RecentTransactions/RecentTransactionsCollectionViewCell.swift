//
//  UpcomingBillsCollectionViewCell.swift
//  BudgetApp
//
//  Created by Suyash Anthwal on 12/02/26.
//

import UIKit

class RecentTransactionsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var BillDate: UILabel!
    @IBOutlet weak var BillIcon: UIImageView!
    @IBOutlet weak var BillName: UILabel!
    @IBOutlet weak var BillAmount: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        BillName.textColor = AppColors.textPrimary
        BillDate.textColor = AppColors.textSecondary
        contentView.backgroundColor = AppColors.card

        // Set tint + symbol rendering mode so SF Symbols show in color
        BillIcon.tintColor = AppColors.brand
        BillIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            paletteColors: [AppColors.brand]
        )
    }

    func configureCell(with bill: Bill) {
        BillName.text = bill.name

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        BillDate.text = formatter.string(from: bill.billDate)

        BillAmount.text = bill.amount.formatted(.currency(code: "INR"))

        // ✅ Apply color when setting each icon too
        BillIcon.image = UIImage(systemName: bill.icon)?
            .withRenderingMode(.alwaysTemplate)
    }

    func configureCell(with transaction: Transaction, categories: [Category]) {
        BillName.text = transaction.name
        BillDate.text = timestampText(for: transaction.timestamp)

        let amount = transaction.amount.formatted(.currency(code: "INR"))

        if transaction.type == .income {
            BillAmount.text = "+ \(amount)"
            BillAmount.textColor = AppColors.brand
            BillIcon.image = UIImage(systemName: "indianrupeesign.circle.fill")?
                .withRenderingMode(.alwaysTemplate)
            BillIcon.tintColor = AppColors.brand
        } else {
            BillAmount.text = "- \(amount)"
            BillAmount.textColor = AppColors.error

            if let id = transaction.categoryId,
               let category = categories.first(where: { $0.id == id }) {
                BillIcon.image = UIImage(systemName: category.icon)?
                    .withRenderingMode(.alwaysTemplate)
            } else {
                BillIcon.image = UIImage(systemName: "questionmark")?
                    .withRenderingMode(.alwaysTemplate)
            }
            BillIcon.tintColor = AppColors.brand
        }
    }

    private func timestampText(for date: Date) -> String {
        let formatter = DateFormatter()

        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
        } else {
            formatter.dateFormat = "d MMM"
        }

        return formatter.string(from: date)
    }
}
