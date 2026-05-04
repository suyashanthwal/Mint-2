
import UIKit

class BudgetCategoriesCollectionViewCell: UICollectionViewCell {
    
    
    @IBOutlet weak var IconView: UIView!
    @IBOutlet weak var Icon: UIImageView!
    @IBOutlet weak var Name: UILabel!
    @IBOutlet weak var Amount: UILabel!

    var onSetLimitTapped: (() -> Void)?

    private lazy var setLimitButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = AppColors.brandLight
        configuration.baseForegroundColor = AppColors.brand
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            return attributes
        }
        button.configuration = configuration
        button.addTarget(self, action: #selector(setLimitTapped), for: .touchUpInside)
        return button
    }()
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.backgroundColor = AppColors.card
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        Name.font = .systemFont(ofSize: 13, weight: .semibold)
        Name.adjustsFontSizeToFitWidth = true
        Name.minimumScaleFactor = 0.82
        Amount.font = .systemFont(ofSize: 12, weight: .bold)
        Amount.adjustsFontSizeToFitWidth = true
        Amount.minimumScaleFactor = 0.78
        setupSetLimitButton()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onSetLimitTapped = nil
        Amount.isHidden = true
        setLimitButton.isHidden = true
    }
    
    func configureCategoryCell(category: Category) {
        Name.text = category.name
        Name.textColor = AppColors.textPrimary
        
        let color = UIColor(hex: category.color)
        
        Icon.image = UIImage(systemName: category.icon)?.withRenderingMode(.alwaysTemplate)
        Icon.tintColor = color
        
        IconView.backgroundColor = color.withAlphaComponent(0.15)
        IconView.layer.cornerRadius = 10

        let spent = max(category.budget - category.remaining, 0)
        let spentValue = currencyFormatter.string(from: NSNumber(value: spent)) ?? "₹0"
        let budgetValue = currencyFormatter.string(from: NSNumber(value: category.budget)) ?? "₹0"

        Amount.text = category.budget > 0 ? "\(spentValue) / \(budgetValue)" : spentValue
        Amount.textColor = category.isOver ? AppColors.error : AppColors.textPrimary

        let hasLimit = category.budget > 0
        Amount.isHidden = !hasLimit
        setLimitButton.isHidden = hasLimit
        setLimitButton.configuration?.title = "Set limit"
        setLimitButton.accessibilityLabel = "Set limit for \(category.name)"
    }

    private func setupSetLimitButton() {
        Amount.isHidden = true
        contentView.addSubview(setLimitButton)

        NSLayoutConstraint.activate([
            setLimitButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            setLimitButton.centerYAnchor.constraint(equalTo: IconView.centerYAnchor),
            setLimitButton.leadingAnchor.constraint(greaterThanOrEqualTo: Name.trailingAnchor, constant: 12),
            setLimitButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 28)
        ])
    }

    @objc private func setLimitTapped() {
        onSetLimitTapped?()
    }
}
