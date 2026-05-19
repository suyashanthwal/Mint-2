import UIKit

final class GoalBadgeCollectionViewCell: UICollectionViewCell {

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var ringContainerView: UIView!
    @IBOutlet private weak var imageContainerView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var completedDotView: UIView!

    private let trackLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private var currentGoalID: UUID?
    private var imageProcessingTask: Task<Void, Never>?

    var contextMenuPreviewView: UIView {
        cardView
    }

    override var isHighlighted: Bool {
        didSet { updateInteractionAppearance() }
    }

    override var isSelected: Bool {
        didSet { updateInteractionAppearance() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        applyStyle()
        ringContainerView.layer.addSublayer(trackLayer)
        ringContainerView.layer.addSublayer(highlightLayer)
        updateInteractionAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentGoalID = nil
        imageProcessingTask?.cancel()
        imageProcessingTask = nil
        imageView.image = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        cardView.layer.cornerRadius = 22
        imageContainerView.layer.cornerRadius = imageContainerView.bounds.width / 2
        completedDotView.layer.cornerRadius = completedDotView.bounds.width / 2
        updateRing()
    }

    private func applyStyle() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear

        cardView.backgroundColor = .clear
        imageContainerView.backgroundColor = UIColor(hex: "#11162F")
        imageContainerView.layer.borderWidth = 1
        imageContainerView.layer.borderColor = UIColor.white.withAlphaComponent(0.05).cgColor
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        titleLabel.textColor = .white
        titleLabel.font = MintFont.space(size: 13, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        completedDotView.backgroundColor = UIColor(hex: "#33D95E")
        completedDotView.layer.borderWidth = 2
        completedDotView.layer.borderColor = UIColor(hex: "#070819").cgColor
    }

    private func updateInteractionAppearance() {
        let pressed = isHighlighted || isSelected
        let scale: CGFloat = pressed ? 0.98 : 1
        cardView.transform = CGAffineTransform(scaleX: scale, y: scale)
        titleLabel.alpha = pressed ? 0.92 : 1
    }

    func configure(with goal: Goal) {
        currentGoalID = goal.id
        titleLabel.text = goal.name

        if let loadedImage = GoalImageStore.loadSavedImage(for: goal) {
            imageView.image = loadedImage.image
            imageView.tintColor = nil
            imageProcessingTask = GoalImageStore.migrateLegacyImageToSubjectOnlyIfNeeded(
                loadedImage,
                for: goal.id
            ) { [weak self] processedImage in
                guard let self, self.currentGoalID == goal.id else { return }
                self.imageView.image = processedImage
                self.imageView.tintColor = nil
            }
            return
        }

        if let imageName = goal.imageName,
           let image = UIImage(named: imageName) {
            imageView.image = image
            imageView.tintColor = nil
            return
        }

        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        imageView.image = UIImage(systemName: goal.iconName, withConfiguration: config)?
            .withTintColor(.white.withAlphaComponent(0.9), renderingMode: .alwaysOriginal)
    }

    private func updateRing() {
        let inset: CGFloat = 4
        let ringRect = ringContainerView.bounds.insetBy(dx: inset, dy: inset)
        let start = -CGFloat.pi / 2
        let end = (CGFloat.pi * 3 / 2)
        let trackPath = UIBezierPath(arcCenter: CGPoint(x: ringRect.midX, y: ringRect.midY),
                                     radius: ringRect.width / 2,
                                     startAngle: start,
                                     endAngle: end,
                                     clockwise: true)

        trackLayer.frame = ringContainerView.bounds
        trackLayer.path = trackPath.cgPath
        trackLayer.strokeColor = UIColor.white.withAlphaComponent(0.22).cgColor
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = 3

        let shineStart = -CGFloat.pi * 0.92
        let shineEnd = shineStart + (.pi * 0.42)
        let shinePath = UIBezierPath(arcCenter: CGPoint(x: ringRect.midX, y: ringRect.midY),
                                     radius: ringRect.width / 2,
                                     startAngle: shineStart,
                                     endAngle: shineEnd,
                                     clockwise: true)

        highlightLayer.frame = ringContainerView.bounds
        highlightLayer.path = shinePath.cgPath
        highlightLayer.strokeColor = UIColor(hex: "#E5BE33").cgColor
        highlightLayer.fillColor = UIColor.clear.cgColor
        highlightLayer.lineWidth = 3.2
        highlightLayer.lineCap = .round
        highlightLayer.shadowOpacity = 0
    }
}
