
import UIKit

class BudgetCategoriesCollectionViewCell: UICollectionViewCell {
    
    
    @IBOutlet weak var IconView: UIView!
    @IBOutlet weak var Icon: UIImageView!
    @IBOutlet weak var Name: UILabel!
    @IBOutlet weak var Amount: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.backgroundColor = AppColors.card
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
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
    }
}
