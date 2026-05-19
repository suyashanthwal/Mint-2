import UIKit

final class ReachedGoalsCollectionViewCell: UICollectionViewCell {

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var thumbnailContainerView: UIView!
    @IBOutlet private weak var thumbnailImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var accentDotView: UIView!
    private var currentGoalID: UUID?
    private var imageProcessingTask: Task<Void, Never>?

    override func awakeFromNib() {
        super.awakeFromNib()
        applyStyle()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentGoalID = nil
        imageProcessingTask?.cancel()
        imageProcessingTask = nil
        thumbnailImageView.image = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        cardView.layer.cornerRadius = 20
        thumbnailContainerView.layer.cornerRadius = 14
        accentDotView.layer.cornerRadius = accentDotView.bounds.width / 2
        layer.shadowPath = UIBezierPath(
            roundedRect: cardView.frame,
            cornerRadius: cardView.layer.cornerRadius
        ).cgPath
    }

    private func applyStyle() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        contentView.clipsToBounds = false
        clipsToBounds = false
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 8)

        cardView.backgroundColor = UIColor(hex: "#172349")
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor

        thumbnailContainerView.backgroundColor = UIColor(hex: "#0F1633")
        thumbnailImageView.contentMode = .scaleAspectFit
        thumbnailImageView.clipsToBounds = true

        titleLabel.textColor = .white
        titleLabel.font = MintFont.space(size: 17, weight: .bold)
        titleLabel.numberOfLines = 1

        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.48)
        subtitleLabel.font = MintFont.space(size: 11, weight: .medium)
        subtitleLabel.numberOfLines = 1

        amountLabel.textColor = UIColor(hex: "#1EE579")
        amountLabel.font = MintFont.space(size: 17, weight: .bold)
        amountLabel.textAlignment = .right
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.78

        accentDotView.backgroundColor = UIColor(hex: "#FFC529")
        accentDotView.layer.borderWidth = 2
        accentDotView.layer.borderColor = UIColor(hex: "#162246").cgColor
    }

    func configure(with goal: Goal) {
        currentGoalID = goal.id
        titleLabel.text = goal.name
        amountLabel.text = "₹\(Int(goal.targetAmount))"

        if let completedOn = goal.completedOn {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM yyyy"
            subtitleLabel.text = "Purchased on \(formatter.string(from: completedOn))"
        } else {
            subtitleLabel.text = "Purchased"
        }

        if let loadedImage = GoalImageStore.loadSavedImage(for: goal) {
            thumbnailImageView.image = loadedImage.image
            thumbnailImageView.tintColor = nil
            imageProcessingTask = GoalImageStore.migrateLegacyImageToSubjectOnlyIfNeeded(
                loadedImage,
                for: goal.id
            ) { [weak self] processedImage in
                guard let self, self.currentGoalID == goal.id else { return }
                self.thumbnailImageView.image = processedImage
                self.thumbnailImageView.tintColor = nil
            }
            return
        }

        if let imageName = goal.imageName,
           let image = UIImage(named: imageName) {
            thumbnailImageView.image = image
            thumbnailImageView.tintColor = nil
            return
        }

        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        thumbnailImageView.image = UIImage(systemName: goal.iconName, withConfiguration: config)?
            .withTintColor(.white.withAlphaComponent(0.9), renderingMode: .alwaysOriginal)
    }
}
