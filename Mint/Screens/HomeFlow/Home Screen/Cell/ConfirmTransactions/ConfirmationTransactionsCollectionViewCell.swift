
import UIKit

class ConfirmationTransactionsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var BillDate: UILabel!
    @IBOutlet weak var BillIcon: UIImageView!
    @IBOutlet weak var BillName: UILabel!
    @IBOutlet weak var BillAmount: UILabel!
    @IBOutlet weak var noButton: UIButton!
    @IBOutlet weak var yesButton: UIButton!

    var onApprove: (() -> Void)?
    var onDiscard: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()

        BillName.textColor = AppColors.textPrimary
        BillDate.textColor = AppColors.textSecondary
        contentView.backgroundColor = AppColors.card
        noButton.tintColor = AppColors.error
        yesButton.tintColor = AppColors.brand

        BillIcon.tintColor = AppColors.brand
        BillIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            paletteColors: [AppColors.brand]
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onApprove = nil
        onDiscard = nil
    }

    @IBAction func yesTapped(_ sender: Any) {
        onApprove?()
    }
    @IBAction func noTapped(_ sender: Any) {
        onDiscard?()
    }
    func configureCell(with bill: Bill) {
        BillName.text = bill.name

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        BillDate.text = formatter.string(from: bill.billDate)

        BillAmount.text = bill.amount.formatted(.currency(code: "INR"))

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

    func configureCell(with bufferedTransaction: BufferedTransaction, categories: [Category]) {
        configureCell(with: bufferedTransaction.asTransaction, categories: categories)
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
