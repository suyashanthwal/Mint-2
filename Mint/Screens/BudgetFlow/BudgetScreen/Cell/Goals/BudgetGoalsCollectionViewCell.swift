
import UIKit

class BudgetGoalsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var GoalsTitleLabel: UILabel!
    @IBOutlet weak var GoalsAmountLabel: UILabel!
    @IBOutlet weak var GoalsProgressView: UIProgressView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.backgroundColor = AppColors.card
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
    }
    
    func configure(goal: Goal) {
        
        GoalsTitleLabel.text = goal.name
        GoalsTitleLabel.textColor = AppColors.textPrimary
        
        let currentStr = currencyFormatter.string(from: NSNumber(value: goal.currentlySaved)) ?? "₹0"
        let targetStr = currencyFormatter.string(from: NSNumber(value: goal.targetAmount)) ?? "₹0"
        
        GoalsAmountLabel.text = "\(currentStr) / \(targetStr)"
        GoalsAmountLabel.textColor = AppColors.textPrimary
        
        let progress = Float(goal.currentlySaved / goal.targetAmount)
        GoalsProgressView.progress = progress
        
        GoalsProgressView.trackTintColor = UIColor.systemGray5
        GoalsProgressView.progressTintColor = AppColors.brand
        GoalsProgressView.transform = CGAffineTransform(scaleX: 1, y: 3)
        GoalsProgressView.layer.cornerRadius = 4
        GoalsProgressView.clipsToBounds = true
        
        }
    
    
}
