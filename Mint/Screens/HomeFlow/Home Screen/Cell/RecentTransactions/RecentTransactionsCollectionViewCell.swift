
import UIKit

class RecentTransactionsCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var BillDate: UILabel!
    @IBOutlet weak var BillIcon: UIImageView!
    @IBOutlet weak var BillIconBackgroundView: UIView!
    @IBOutlet weak var BillName: UILabel!
    @IBOutlet weak var BillAmount: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        clipsToBounds = false
        contentView.clipsToBounds = false
        BillName.textColor = AppColors.textPrimary
        BillDate.textColor = AppColors.textSecondary
        BillName.font = MintFont.space(size: BillName.font.pointSize, weight: .semibold)
        BillDate.font = MintFont.space(size: BillDate.font.pointSize, weight: .regular)
        BillAmount.font = MintFont.space(size: BillAmount.font.pointSize, weight: .heavy)
        contentView.backgroundColor = AppColors.card

        BillIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 18,
            weight: .medium
        )
        applyIconAppearance(
            tint: AppColors.brand,
            background: AppColors.brandLight.withAlphaComponent(0.35)
        )
    }

    func configureCell(with bill: Bill) {
        BillName.text = bill.name

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        BillDate.text = formatter.string(from: bill.billDate)

        BillAmount.text = bill.amount.formatted(.currency(code: "INR"))
        BillAmount.textColor = AppColors.textPrimary
        normalizeTextAppearance()

        BillIcon.image = UIImage(systemName: bill.icon)?
            .withRenderingMode(.alwaysTemplate)
        applyIconAppearance(
            tint: AppColors.brand,
            background: AppColors.brandLight.withAlphaComponent(0.35)
        )
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
            applyIconAppearance(
                tint: AppColors.brand,
                background: AppColors.brandLight.withAlphaComponent(0.35)
            )
        } else {
            BillAmount.text = "- \(amount)"
            BillAmount.textColor = AppColors.error

            if let id = transaction.categoryId,
               let category = categories.first(where: { $0.id == id }) {
                let categoryColor = UIColor(hex: category.color)
                BillIcon.image = UIImage(systemName: category.icon)?
                    .withRenderingMode(.alwaysTemplate)
                applyIconAppearance(
                    tint: categoryColor,
                    background: categoryColor.withAlphaComponent(0.15)
                )
            } else {
                BillIcon.image = UIImage(systemName: "questionmark")?
                    .withRenderingMode(.alwaysTemplate)
                applyIconAppearance(
                    tint: AppColors.brand,
                    background: AppColors.brandLight.withAlphaComponent(0.35)
                )
            }
        }
        normalizeTextAppearance()
    }

    private func applyIconAppearance(tint: UIColor, background: UIColor) {
        BillIcon.tintColor = tint
        BillIconBackgroundView.backgroundColor = background
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

    private func normalizeTextAppearance() {
        [BillName, BillDate, BillAmount].forEach { label in
            guard let label, let text = label.text else { return }
            label.attributedText = NSAttributedString(
                string: text,
                attributes: [
                    .font: label.font as Any,
                    .foregroundColor: label.textColor as Any,
                    .kern: 0
                ]
            )
        }
    }
}
