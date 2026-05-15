import UIKit

final class GoalAddButtonCollectionViewCell: UICollectionViewCell {

    @IBOutlet private weak var addButton: UIButton!

    var onTap: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.backgroundColor = .clear
        backgroundColor = .clear
        addButton.layer.cornerCurve = .continuous
    }

    @IBAction private func addButtonTapped(_ sender: UIButton) {
        onTap?()
    }
}
