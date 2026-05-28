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
        addButton.backgroundColor = UIColor(hex: "#080A21")
        addButton.layer.borderWidth = 2
        addButton.layer.borderColor = UIColor(hex: "#2EF00E").cgColor
        addButton.setTitleColor(.white, for: .normal)
        addButton.titleLabel?.font = MintFont.space(size: 17, weight: .bold)
        updateInteractionAppearance()
    }

    @IBAction private func addButtonTapped(_ sender: UIButton) {
        onTap?()
    }

    private func updateInteractionAppearance() {
        addButton.alpha = (isHighlighted || isSelected) ? 0.92 : 1
    }
}
