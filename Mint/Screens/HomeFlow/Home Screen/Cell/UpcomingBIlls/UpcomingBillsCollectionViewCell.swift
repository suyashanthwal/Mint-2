
import UIKit

class UpcomingBillsCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var Title: UILabel?
    @IBOutlet weak var Amount: UILabel?
    @IBOutlet weak var iconImageView: UIImageView?
    @IBOutlet weak var cardContainerView: UIView?
    @IBOutlet weak var statusFrameView: UIView?
    @IBOutlet weak var timelineVerticalLineView: UIView?
    @IBOutlet weak var timelineDotView: UIView?
    @IBOutlet weak var timelineConnectorView: UIView?
    @IBOutlet weak var dateLabel: UILabel?
    @IBOutlet weak var timelineConnectorTrailingConstraint: NSLayoutConstraint?
    
    @IBOutlet private weak var dotView: UIView!
    @IBOutlet private weak var dotLabel: UILabel!

    private let urgentThreshold = 3
    private let brandLogoLabel = UILabel()

    override func awakeFromNib() {
        super.awakeFromNib()

        clipsToBounds = false
        contentView.clipsToBounds = false

        let styledContentView = cardContainerView ?? contentView
        styledContentView.layer.cornerRadius = 8
        styledContentView.layer.masksToBounds = false
        styledContentView.backgroundColor = AppColors.card

        statusFrameView?.layer.cornerRadius = 8
        statusFrameView?.layer.masksToBounds = false
        statusFrameView?.backgroundColor = .clear
        dotView.layer.cornerRadius = 4
        dotView.clipsToBounds = true
        dotLabel.font = MintFont.space(size: 8, weight: .bold)
        dotLabel.textColor = AppColors.textSecondary
        dotLabel.textAlignment = .left

        contentView.layer.cornerRadius  = 8
        contentView.layer.masksToBounds = false
        contentView.backgroundColor     = .clear
        Title?.textColor                = AppColors.textPrimary
        Amount?.textColor               = AppColors.textPrimary
        dateLabel?.textColor            = AppColors.textPrimary
        iconImageView?.tintColor        = AppColors.textPrimary
        timelineConnectorView?.backgroundColor = AppColors.cardBorder
        timelineVerticalLineView?.backgroundColor = AppColors.cardBorder
        timelineDotView?.backgroundColor = AppColors.cardBorder
        timelineDotView?.layer.cornerRadius = (timelineDotView?.bounds.width ?? 14) / 2
        timelineConnectorTrailingConstraint?.constant = -42

        Title?.textAlignment = .center
        Amount?.textAlignment = .center
        dateLabel?.textAlignment = .center
        Title?.font = MintFont.space(size: 11, weight: .semibold)
        Amount?.font = MintFont.space(size: 14, weight: .heavy)
        dateLabel?.font = MintFont.space(size: 10, weight: .bold)
        dateLabel?.backgroundColor = UIColor(hex: "#253766")
        dateLabel?.layer.cornerRadius = 6
        dateLabel?.clipsToBounds = true

        iconImageView?.layer.cornerRadius = 18
        iconImageView?.clipsToBounds = true
        installBrandLogoLabel()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        timelineDotView?.layer.cornerRadius = (timelineDotView?.bounds.width ?? 14) / 2
    }

    func configureCell(with bill: Bill, isFirst: Bool, isLast: Bool) {
        if bill.isPaid {
            Title?.text = bill.name
            Amount?.text = compactCurrency(bill.amount)
            dateLabel?.text = shortDate(bill.billDate)
            iconImageView?.image = iconImage(named: bill.icon)
            applyBrandIcon(for: bill.name, fallbackIcon: bill.icon)
            applyTimelineStyle(for: bill.billDate, isPaid: true, isFirst: isFirst, isLast: isLast)
            normalizeTextAppearance()
            return
        }

        Title?.text  = bill.name
        Amount?.text = compactCurrency(bill.amount)
        dateLabel?.text = shortDate(bill.billDate)
        iconImageView?.image = iconImage(named: bill.icon)
        applyBrandIcon(for: bill.name, fallbackIcon: bill.icon)
        applyTimelineStyle(for: bill.billDate, isPaid: false, isFirst: isFirst, isLast: isLast)
        normalizeTextAppearance()
    }

    func configureCell(with subscription: RecurringPayment, isFirst: Bool, isLast: Bool) {
        Title?.text = subscription.name
        Amount?.text = compactCurrency(subscription.amount)
        dateLabel?.text = shortDate(subscription.nextDate)
        let icon = subscription.icon ?? "creditcard.fill"
        iconImageView?.image = iconImage(named: icon)
        applyBrandIcon(for: subscription.name, fallbackIcon: icon)
        applyTimelineStyle(for: subscription.nextDate, isPaid: false, isFirst: isFirst, isLast: isLast)
        normalizeTextAppearance()
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date).lowercased()
    }

    private func compactCurrency(_ amount: Double) -> String {
        "₹\(Int(amount.rounded()))"
    }

    private func applyTimelineStyle(for dueDate: Date, isPaid: Bool, isFirst: Bool, isLast: Bool) {
        let today = Calendar.current.startOfDay(for: Date())
        let dueDay = Calendar.current.startOfDay(for: dueDate)
        let daysUntilDue = Calendar.current.dateComponents([.day], from: today, to: dueDay).day ?? 0

        let statusColor: UIColor
        let statusText: String
        let borderWidth: CGFloat

        let isPastDue = daysUntilDue < 0

        if isPaid {
            statusColor = AppColors.cardBorder
            statusText = "Paid"
            borderWidth = 1
            contentView.alpha = 0.72
        } else if isPastDue {
            statusColor = AppColors.error
            statusText = "Overdue"
            borderWidth = 1.5
            contentView.alpha = 1
        } else {
            statusColor = AppColors.orange
            statusText = "Upcoming"
            borderWidth = 1.25
            contentView.alpha = 1
        }

        dotView.backgroundColor = statusColor
        dotLabel.text = statusText
        dotLabel.textColor = isPaid ? AppColors.textSecondary : statusColor
        statusFrameView?.layer.borderColor = statusColor.cgColor
        statusFrameView?.layer.borderWidth = borderWidth
        cardContainerView?.backgroundColor = AppColors.card
        dateLabel?.backgroundColor = isPastDue && !isPaid
            ? AppColors.error
            : UIColor(hex: "#253766")
        dateLabel?.textColor = AppColors.textPrimary

        timelineVerticalLineView?.backgroundColor = AppColors.cardBorder
        timelineDotView?.backgroundColor = AppColors.cardBorder
        timelineConnectorView?.backgroundColor = AppColors.cardBorder

        timelineVerticalLineView?.isHidden = false
        timelineDotView?.isHidden = false
        timelineConnectorView?.isHidden = isLast && !isFirst
    }

    private func iconImage(named name: String) -> UIImage? {
        UIImage(named: name) ?? UIImage(systemName: name)
    }

    private func normalizeTextAppearance() {
        [
            (Title, Title?.font, Title?.textColor),
            (Amount, Amount?.font, Amount?.textColor),
            (dateLabel, dateLabel?.font, dateLabel?.textColor),
            (dotLabel, dotLabel.font, dotLabel.textColor)
        ].forEach { label, font, color in
            guard let label, let font, let color, let text = label.text else { return }
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
              let iconImageView,
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
        iconImageView?.isHidden = false
        iconImageView?.backgroundColor = .clear
        iconImageView?.tintColor = AppColors.textPrimary

        if normalized.contains("youtube") {
            iconImageView?.image = UIImage(systemName: "play.rectangle.fill")
            iconImageView?.tintColor = UIColor(hex: "#FF2D16")
            return
        }

        if normalized.contains("netflix") {
            iconImageView?.isHidden = true
            brandLogoLabel.isHidden = false
            brandLogoLabel.text = "N"
            brandLogoLabel.font = MintFont.space(size: 12, weight: .bold)
            brandLogoLabel.textColor = .white
            brandLogoLabel.backgroundColor = UIColor(hex: "#F41424")
            brandLogoLabel.layer.cornerRadius = 18
            return
        }

        if normalized.contains("prime") {
            iconImageView?.isHidden = true
            brandLogoLabel.isHidden = false
            brandLogoLabel.text = "prime"
            brandLogoLabel.font = MintFont.space(size: 9, weight: .bold)
            brandLogoLabel.textColor = UIColor(hex: "#2ED7FF")
            brandLogoLabel.backgroundColor = .clear
            brandLogoLabel.layer.cornerRadius = 0
            return
        }

        iconImageView?.image = iconImage(named: fallbackIcon)
    }
}

final class DatePillLabel: UILabel {
    var contentInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4) {
        didSet { invalidateIntrinsicContentSize() }
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func textRect(
        forBounds bounds: CGRect,
        limitedToNumberOfLines numberOfLines: Int
    ) -> CGRect {
        let insetBounds = bounds.inset(by: contentInsets)
        let rect = super.textRect(
            forBounds: insetBounds,
            limitedToNumberOfLines: numberOfLines
        )
        return rect.inset(by: UIEdgeInsets(
            top: -contentInsets.top,
            left: -contentInsets.left,
            bottom: -contentInsets.bottom,
            right: -contentInsets.right
        ))
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }
}
