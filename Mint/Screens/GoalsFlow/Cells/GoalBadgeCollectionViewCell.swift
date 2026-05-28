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
    private let checkmarkImageView = UIImageView()
    private var currentGoalID: UUID?
    private var imageProcessingTask: Task<Void, Never>?
    private var isTouchPressed = false

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
        imageContainerView.backgroundColor = UIColor(hex: "#17183A")
        imageContainerView.layer.borderWidth = 0
        imageContainerView.layer.borderColor = UIColor.clear.cgColor
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        titleLabel.textColor = .white
        titleLabel.font = MintFont.space(size: 13, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        completedDotView.backgroundColor = UIColor(hex: "#39E019")
        completedDotView.layer.borderWidth = 5
        completedDotView.layer.borderColor = UIColor(hex: "#050713").cgColor
        completedDotView.layer.shadowColor = UIColor.black.cgColor
        completedDotView.layer.shadowOpacity = 0.28
        completedDotView.layer.shadowRadius = 10
        completedDotView.layer.shadowOffset = CGSize(width: 0, height: 4)

        if checkmarkImageView.superview == nil {
            checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
            checkmarkImageView.image = UIImage(
                systemName: "checkmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            )
            checkmarkImageView.tintColor = .white
            completedDotView.addSubview(checkmarkImageView)
            NSLayoutConstraint.activate([
                checkmarkImageView.centerXAnchor.constraint(equalTo: completedDotView.centerXAnchor),
                checkmarkImageView.centerYAnchor.constraint(equalTo: completedDotView.centerYAnchor),
                checkmarkImageView.widthAnchor.constraint(equalToConstant: 14),
                checkmarkImageView.heightAnchor.constraint(equalToConstant: 14)
            ])
        }
    }

    private func updateInteractionAppearance() {
        let pressed = isHighlighted || isSelected || isTouchPressed
        cardView.transform = .identity
        cardView.alpha = pressed ? 0.92 : 1
    }

    func setTouchPressed(_ pressed: Bool) {
        guard isTouchPressed != pressed else { return }
        isTouchPressed = pressed
        updateInteractionAppearance()
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
        let inset: CGFloat = 2
        let ringRect = ringContainerView.bounds.insetBy(dx: inset, dy: inset)
        let center = CGPoint(x: ringRect.midX, y: ringRect.midY)
        let radius = ringRect.width / 2
        let circumference = 2 * CGFloat.pi * radius
        let gapLength = circumference * 0.06
        let segmentLength = (circumference - (gapLength * 4)) / 4
        let segmentSweep = segmentLength / radius
        let startAngle = (-CGFloat.pi / 2) - (segmentSweep / 2)
        let endAngle = startAngle + (CGFloat.pi * 2)
        let ringPath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )

        trackLayer.frame = ringContainerView.bounds
        trackLayer.path = ringPath.cgPath
        trackLayer.strokeColor = UIColor(hex: "#D4A100").cgColor
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = 3
        trackLayer.lineCap = .butt
        trackLayer.lineDashPattern = [NSNumber(value: Double(segmentLength)), NSNumber(value: Double(gapLength))]
        trackLayer.lineDashPhase = 0

        highlightLayer.frame = ringContainerView.bounds
        highlightLayer.path = ringPath.cgPath
        highlightLayer.strokeColor = UIColor.clear.cgColor
        highlightLayer.fillColor = UIColor.clear.cgColor
        highlightLayer.lineWidth = 0
        highlightLayer.shadowOpacity = 0
    }
}
