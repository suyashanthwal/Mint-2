import UIKit

final class OngoingGoalCollectionViewCell: UICollectionViewCell {

    enum Mode {
        case active
        case readyToPurchase
        case inactive
    }

    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var progressBaseView: UIView!
    @IBOutlet private weak var progressFillView: UIView!
    @IBOutlet private weak var progressFillWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var ghostNameLabel: UILabel!
    @IBOutlet private weak var statusChipContainerView: UIView!
    @IBOutlet private weak var statusChipLabel: UILabel!
    @IBOutlet private weak var amountPillView: UIView!
    @IBOutlet private weak var amountLabel: UILabel!

    @IBOutlet private weak var goalImageView: UIImageView!
    @IBOutlet private weak var goalTitleLabel: UILabel!
    @IBOutlet private weak var goalSubtitleLabel: UILabel!
    @IBOutlet private weak var actionButton: UIButton!

    var onPrimaryAction: (() -> Void)?

    private var currentProgress: CGFloat = 0
    private var currentMode: Mode = .active
    private var currentGoalID: UUID?
    private var imageProcessingTask: Task<Void, Never>?
    private let baseGradientLayer = CAGradientLayer()
    private let fillGradientLayer = CAGradientLayer()

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
        applyBaseStyle()
        configureGradientLayers()
        updateInteractionAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageProcessingTask?.cancel()
        imageProcessingTask = nil
        onPrimaryAction = nil
        currentGoalID = nil
        goalImageView.image = nil
        statusChipContainerView.isHidden = true
        statusChipContainerView.layer.borderWidth = 0
        statusChipContainerView.layer.borderColor = UIColor.clear.cgColor
        currentProgress = 0
        currentMode = .active
        goalImageView.alpha = 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateProgressFillWidth()
        progressFillView.layer.cornerRadius = 0
        baseGradientLayer.frame = progressBaseView.bounds
        fillGradientLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: progressFillWidthConstraint.constant,
            height: progressBaseView.bounds.height
        )
        layer.shadowPath = UIBezierPath(
            roundedRect: cardView.frame,
            cornerRadius: cardView.layer.cornerRadius
        ).cgPath
    }

    private func applyBaseStyle() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.16
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 10)

        cardView.layer.cornerCurve = .continuous
    }

    private func updateInteractionAppearance() {
        let pressed = isHighlighted || isSelected
        cardView.transform = pressed ? CGAffineTransform(scaleX: 0.99, y: 0.99) : .identity
        layer.shadowOpacity = pressed ? 0.12 : 0.16
    }

    private func configureGradientLayers() {
        baseGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        baseGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        baseGradientLayer.locations = [0.0, 0.58, 1.0]
        progressBaseView.layer.insertSublayer(baseGradientLayer, at: 0)

        fillGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        fillGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        fillGradientLayer.locations = [0.0, 1.0]
        progressFillView.layer.insertSublayer(fillGradientLayer, at: 0)
    }

    private func updateProgressFillWidth() {
        let availableWidth = progressBaseView.bounds.width
        let clampedProgress = max(0, min(currentProgress, 1))
        progressFillWidthConstraint.constant = availableWidth * clampedProgress
        baseGradientLayer.opacity = baseGradientOpacity(for: currentMode, progress: clampedProgress)
        fillGradientLayer.opacity = clampedProgress > 0.001 ? 1 : 0
    }

    private func baseGradientOpacity(for mode: Mode, progress: CGFloat) -> Float {
        let softenedProgress = max(0, progress - 0.03)

        switch mode {
        case .active:
            return Float(min(0.45, softenedProgress * 0.55))
        case .readyToPurchase:
            return Float(max(0.16, min(0.55, progress * 0.6)))
        case .inactive:
            return Float(min(0.22, softenedProgress * 0.28))
        }
    }

    private func applyGradientPalette(for mode: Mode) {
        switch mode {
        case .active:
            baseGradientLayer.colors = [
                UIColor(hex: "#1F4F23").withAlphaComponent(0.40).cgColor,
                UIColor(hex: "#2A602B").withAlphaComponent(0.18).cgColor,
                UIColor(hex: "#265928").withAlphaComponent(0.0).cgColor
            ]
            fillGradientLayer.colors = [
                UIColor(hex: "#2E732C").cgColor,
                UIColor(hex: "#4A9437").cgColor
            ]
        case .readyToPurchase:
            baseGradientLayer.colors = [
                UIColor(hex: "#245723").withAlphaComponent(0.48).cgColor,
                UIColor(hex: "#326B2D").withAlphaComponent(0.22).cgColor,
                UIColor(hex: "#2E642A").withAlphaComponent(0.02).cgColor
            ]
            fillGradientLayer.colors = [
                UIColor(hex: "#357E2F").cgColor,
                UIColor(hex: "#53A13D").cgColor
            ]
        case .inactive:
            baseGradientLayer.colors = [
                UIColor(hex: "#223028").withAlphaComponent(0.38).cgColor,
                UIColor(hex: "#293730").withAlphaComponent(0.20).cgColor,
                UIColor(hex: "#293730").withAlphaComponent(0.0).cgColor
            ]
            fillGradientLayer.colors = [
                UIColor(hex: "#3B5240").cgColor,
                UIColor(hex: "#506653").cgColor
            ]
        }
    }

    func configure(with goal: Goal, mode: Mode) {
        currentGoalID = goal.id
        currentMode = mode
        currentProgress = CGFloat(goal.progress)

        ghostNameLabel.text = ghostTitle(from: goal.name)
        amountLabel.text = "₹\(Int(goal.currentlySaved))  /  ₹\(Int(goal.targetAmount))"
        goalTitleLabel.text = goal.name
        goalSubtitleLabel.text = subtitle(for: goal, mode: mode)

        switch mode {
        case .active:
            actionButton.setTitle("Add Funds", for: .normal)
            statusChipContainerView.isHidden = true
            statusChipContainerView.layer.borderWidth = 0
            statusChipContainerView.layer.borderColor = UIColor.clear.cgColor
            cardView.alpha = 1
            amountPillView.backgroundColor = UIColor(hex: "#193B1E").withAlphaComponent(0.35)
            actionButton.backgroundColor = UIColor.white.withAlphaComponent(0.11)
            actionButton.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
            actionButton.setTitleColor(.white, for: .normal)
            ghostNameLabel.alpha = 0.07
            goalImageView.alpha = 1

        case .readyToPurchase:
            actionButton.setTitle("Mark Purchased ✓", for: .normal)
            statusChipLabel.text = "Fully Saved"
            statusChipContainerView.isHidden = false
            cardView.alpha = 1
            amountPillView.backgroundColor = UIColor(hex: "#1A421E").withAlphaComponent(0.35)
            actionButton.backgroundColor = UIColor(hex: "#A7DB8B").withAlphaComponent(0.24)
            actionButton.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
            actionButton.setTitleColor(.white, for: .normal)
            statusChipContainerView.backgroundColor = UIColor(hex: "#6F33F6")
            statusChipContainerView.layer.borderWidth = 1
            statusChipContainerView.layer.borderColor = UIColor.white.withAlphaComponent(0.75).cgColor
            ghostNameLabel.alpha = 0.07
            goalImageView.alpha = 1

        case .inactive:
            actionButton.setTitle("Resume Goal", for: .normal)
            statusChipContainerView.isHidden = true
            statusChipContainerView.layer.borderWidth = 0
            statusChipContainerView.layer.borderColor = UIColor.clear.cgColor
            cardView.alpha = 0.94
            amountPillView.backgroundColor = UIColor(hex: "#18251C").withAlphaComponent(0.35)
            actionButton.backgroundColor = UIColor.white.withAlphaComponent(0.09)
            actionButton.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
            actionButton.setTitleColor(.white.withAlphaComponent(0.92), for: .normal)
            ghostNameLabel.alpha = 0.05
            goalImageView.alpha = 0.72
        }

        applyGradientPalette(for: mode)
        applyImage(for: goal)
        setNeedsLayout()
    }

    private func subtitle(for goal: Goal, mode: Mode) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"

        switch mode {
        case .active:
            return "Target Date \(formatter.string(from: goal.targetDate))"
        case .readyToPurchase:
            return "Ready to Purchase"
        case .inactive:
            return "Currently inactive"
        }
    }

    private func ghostTitle(from name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyImage(for goal: Goal) {
        if let pickedImageURL = goal.pickedImageURL,
           let data = try? Data(contentsOf: pickedImageURL),
           let image = UIImage(data: data) {
            goalImageView.image = image
            goalImageView.tintColor = nil
            migrateLegacyPickedImageIfNeeded(
                image,
                goalId: goal.id,
                sourceURL: pickedImageURL
            )
            return
        }

        if let imageName = goal.imageName,
           let image = UIImage(named: imageName) {
            goalImageView.image = image
            goalImageView.tintColor = nil
            return
        }

        let config = UIImage.SymbolConfiguration(pointSize: 42, weight: .medium)
        goalImageView.image = UIImage(systemName: goal.iconName, withConfiguration: config)?
            .withTintColor(.white.withAlphaComponent(currentMode == .inactive ? 0.7 : 0.9), renderingMode: .alwaysOriginal)
    }

    private func migrateLegacyPickedImageIfNeeded(_ image: UIImage, goalId: UUID, sourceURL: URL) {
        guard sourceURL.pathExtension.lowercased() != "png" else { return }

        imageProcessingTask?.cancel()
        imageProcessingTask = Task { [weak self] in
            let processedImage = await GoalImageCutoutProcessor.process(image)
            guard !Task.isCancelled else { return }

            _ = GoalImageStore.save(processedImage, for: goalId)

            await MainActor.run {
                guard let self, self.currentGoalID == goalId, !Task.isCancelled else { return }
                self.goalImageView.image = processedImage
                self.goalImageView.tintColor = nil
            }
        }
    }

    @IBAction private func actionButtonTapped(_ sender: UIButton) {
        onPrimaryAction?()
    }
}
