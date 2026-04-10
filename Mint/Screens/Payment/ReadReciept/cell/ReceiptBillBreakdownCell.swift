import UIKit

struct ReceiptBreakdownRow {
    let title: String
    let value: String
    let isEmphasized: Bool

    init(title: String, value: String, isEmphasized: Bool = false) {
        self.title = title
        self.value = value
        self.isEmphasized = isEmphasized
    }
}

 class ReceiptBillBreakdownCell: UICollectionViewCell {

    static let reuseID = "ReceiptBillBreakdownCell"

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var rowsStackView: UIStackView!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = AppColors.textPrimary

        rowsStackView.axis = .vertical
        rowsStackView.spacing = 12
        rowsStackView.alignment = .fill

        cardView.backgroundColor = AppColors.card
        cardView.layer.cornerRadius = 20
        cardView.layer.masksToBounds = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        clearRows()
    }

    func configure(title: String = "Bill Breakdown", rows: [ReceiptBreakdownRow]) {
        titleLabel.text = title

        clearRows()

        for (index, row) in rows.enumerated() {
            rowsStackView.addArrangedSubview(makeRowView(for: row))

            if index < rows.count - 1 {
                rowsStackView.addArrangedSubview(makeSeparatorView())
            }
        }
    }

    private func clearRows() {
        rowsStackView.arrangedSubviews.forEach { row in
            rowsStackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
    }

    private func makeRowView(for row: ReceiptBreakdownRow) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.alignment = .center
        container.distribution = .fill
        container.spacing = 12

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: row.isEmphasized ? 16 : 14,
                                      weight: row.isEmphasized ? .semibold : .medium)
        titleLabel.textColor = row.isEmphasized ? AppColors.textPrimary : AppColors.textSecondary
        titleLabel.text = row.title

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.font = .systemFont(ofSize: row.isEmphasized ? 16 : 14,
                                      weight: row.isEmphasized ? .bold : .semibold)
        valueLabel.textColor = row.isEmphasized ? AppColors.brand : AppColors.textPrimary
        valueLabel.textAlignment = .right
        valueLabel.text = row.value

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(spacer)
        container.addArrangedSubview(valueLabel)
        return container
    }

    private func makeSeparatorView() -> UIView {
        let separator = UIView()
        separator.backgroundColor = AppColors.sectionBackground
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1)
        ])
        return separator
    }
}
