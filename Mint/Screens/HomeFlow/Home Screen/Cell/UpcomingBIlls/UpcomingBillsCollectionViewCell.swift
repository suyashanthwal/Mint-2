
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

    private let urgentThreshold = 3

    override func awakeFromNib() {
        super.awakeFromNib()

        clipsToBounds = false
        contentView.clipsToBounds = false

        let styledContentView = cardContainerView ?? contentView
        styledContentView.layer.cornerRadius = 12
        styledContentView.layer.masksToBounds = false
        styledContentView.backgroundColor = AppColors.card

        statusFrameView?.layer.cornerRadius = 14
        statusFrameView?.layer.masksToBounds = false
        statusFrameView?.backgroundColor = .clear

        contentView.layer.cornerRadius  = 12
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
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        timelineDotView?.layer.cornerRadius = (timelineDotView?.bounds.width ?? 14) / 2
    }

    func configureCell(with bill: Bill, isFirst: Bool, isLast: Bool) {
        if bill.isPaid {
            Title?.text = bill.name
            Amount?.text = bill.amount.formatted(.currency(code: "INR"))
            dateLabel?.text = shortDate(bill.billDate)
            iconImageView?.image = iconImage(named: bill.icon)
            applyTimelineStyle(for: bill.billDate, isPaid: true, isFirst: isFirst, isLast: isLast)
            return
        }

        Title?.text  = bill.name
        Amount?.text = bill.amount.formatted(.currency(code: "INR"))
        dateLabel?.text = shortDate(bill.billDate)
        iconImageView?.image = iconImage(named: bill.icon)
        applyTimelineStyle(for: bill.billDate, isPaid: false, isFirst: isFirst, isLast: isLast)
    }

    func configureCell(with subscription: RecurringPayment, isFirst: Bool, isLast: Bool) {
        Title?.text = subscription.name
        Amount?.text = subscription.amount.formatted(.currency(code: "INR"))
        dateLabel?.text = shortDate(subscription.nextDate)
        iconImageView?.image = iconImage(named: subscription.icon ?? "creditcard.fill")
        applyTimelineStyle(for: subscription.nextDate, isPaid: false, isFirst: isFirst, isLast: isLast)
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func applyTimelineStyle(for dueDate: Date, isPaid: Bool, isFirst: Bool, isLast: Bool) {
        let today = Calendar.current.startOfDay(for: Date())
        let dueDay = Calendar.current.startOfDay(for: dueDate)
        let daysUntilDue = Calendar.current.dateComponents([.day], from: today, to: dueDay).day ?? 0

        let statusColor: UIColor
        let borderWidth: CGFloat

        if isPaid {
            statusColor = AppColors.cardBorder
            borderWidth = 1
            contentView.alpha = 0.72
        } else if daysUntilDue < 0 || daysUntilDue <= urgentThreshold {
            statusColor = AppColors.error
            borderWidth = 1.5
            contentView.alpha = 1
        } else if daysUntilDue <= 7 {
            statusColor = AppColors.orange
            borderWidth = 1.25
            contentView.alpha = 1
        } else {
            statusColor = AppColors.cardBorder
            borderWidth = 1
            contentView.alpha = 1
        }

        statusFrameView?.layer.borderColor = statusColor.cgColor
        statusFrameView?.layer.borderWidth = borderWidth
        cardContainerView?.backgroundColor = AppColors.card

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
}
