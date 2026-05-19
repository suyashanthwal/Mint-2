import UIKit

final class GoalAddButtonCollectionViewCell: UICollectionViewCell {

    @IBOutlet private weak var addButton: UIButton!

    var onTap: (() -> Void)?

    override var isHighlighted: Bool {
        didSet { updateInteractionAppearance() }
    }

    override var isSelected: Bool {
        didSet { updateInteractionAppearance() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear
        addButton.layer.cornerCurve = .continuous
        updateInteractionAppearance()
    }

    @IBAction private func addButtonTapped(_ sender: UIButton) {
        onTap?()
    }

    private func updateInteractionAppearance() {
        addButton.alpha = (isHighlighted || isSelected) ? 0.92 : 1
    }
}
