import UIKit

struct BudgetBillItem {
    let title: String
    let amount: String
    let date: String
    let symbolName: String
    let dotColor: UIColor
}

final class BillCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "BillCollectionViewCell"
    static let itemSize = CGSize(width: 110, height: 138)

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!
    @IBOutlet private weak var statusFrameView: UIView?

    

    private let brandLogoLabel = UILabel()

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    private func setupUI() {
        clipsToBounds = false
        contentView.clipsToBounds = false
        contentView.backgroundColor = .clear

        cardView.backgroundColor = AppColors.card
        cardView.layer.cornerRadius = 8
        cardView.layer.masksToBounds = false

        statusFrameView?.backgroundColor = .clear
        statusFrameView?.layer.cornerRadius = 8
        statusFrameView?.layer.borderColor = AppColors.cardBorder.cgColor
        statusFrameView?.layer.borderWidth = 1
        statusFrameView?.layer.masksToBounds = false

        iconImageView.tintColor = AppColors.textPrimary
        titleLabel.textColor = AppColors.textPrimary
        amountLabel.textColor = AppColors.textPrimary
        dateLabel.textColor = AppColors.textPrimary
        titleLabel.textAlignment = .center
        amountLabel.textAlignment = .center
        dateLabel.textAlignment = .center
        titleLabel.font = MintFont.space(size: 11, weight: .semibold)
        amountLabel.font = MintFont.space(size: 14, weight: .heavy)
        dateLabel.font = MintFont.space(size: 11, weight: .bold)
        dateLabel.layer.cornerRadius = 6
        dateLabel.clipsToBounds = true

        iconImageView.layer.cornerRadius = 18
        iconImageView.clipsToBounds = true
        installBrandLogoLabel()
    }


    func configure(with item: BudgetBillItem) {
        iconImageView.image = UIImage(systemName: item.symbolName)
        titleLabel.text = item.title
        amountLabel.text = item.amount
        dateLabel.text = item.date
        applyBrandIcon(for: item.title, fallbackIcon: item.symbolName)
        normalizeTextAppearance()
    }

    private func normalizeTextAppearance() {
        [
            (titleLabel, titleLabel.font, titleLabel.textColor),
            (amountLabel, amountLabel.font, amountLabel.textColor),
            (dateLabel, dateLabel.font, dateLabel.textColor)
        ].forEach { label, font, color in
            guard let font, let color, let text = label.text else { return }
            label.attributedText = NSAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .kern: 0
                ]
            )
        }
    }

    private func installBrandLogoLabel() {
        guard brandLogoLabel.superview == nil,
              let iconContainer = iconImageView.superview
        else { return }

        brandLogoLabel.translatesAutoresizingMaskIntoConstraints = false
        brandLogoLabel.textAlignment = .center
        brandLogoLabel.clipsToBounds = true
        iconContainer.addSubview(brandLogoLabel)

        NSLayoutConstraint.activate([
            brandLogoLabel.centerXAnchor.constraint(equalTo: iconImageView.centerXAnchor),
            brandLogoLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            brandLogoLabel.widthAnchor.constraint(equalTo: iconImageView.widthAnchor),
            brandLogoLabel.heightAnchor.constraint(equalTo: iconImageView.heightAnchor)
        ])
    }

    private func applyBrandIcon(for name: String, fallbackIcon: String) {
        let normalized = name.lowercased()
        brandLogoLabel.isHidden = true
        brandLogoLabel.backgroundColor = .clear
        brandLogoLabel.text = nil
        iconImageView.isHidden = false
        iconImageView.backgroundColor = .clear
        iconImageView.tintColor = AppColors.textPrimary

        if normalized.contains("youtube") {
            iconImageView.image = UIImage(systemName: "play.rectangle.fill")
            iconImageView.tintColor = UIColor(hex: "#FF2D16")
            return
        }

        if normalized.contains("netflix") {
            iconImageView.isHidden = true
            brandLogoLabel.isHidden = false
            brandLogoLabel.text = "N"
            brandLogoLabel.font = MintFont.space(size: 12, weight: .bold)
            brandLogoLabel.textColor = .white
            brandLogoLabel.backgroundColor = UIColor(hex: "#F41424")
            brandLogoLabel.layer.cornerRadius = 18
            return
        }

        if normalized.contains("prime") {
            iconImageView.isHidden = true
            brandLogoLabel.isHidden = false
            brandLogoLabel.text = "prime"
            brandLogoLabel.font = MintFont.space(size: 9, weight: .bold)
            brandLogoLabel.textColor = UIColor(hex: "#2ED7FF")
            brandLogoLabel.backgroundColor = .clear
            brandLogoLabel.layer.cornerRadius = 0
            return
        }

        iconImageView.image = UIImage(named: fallbackIcon) ?? UIImage(systemName: fallbackIcon)
    }
}
