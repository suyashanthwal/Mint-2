
import UIKit
import PhotosUI

class OngoingGoalCollectionViewCell: UICollectionViewCell {
 
    

    @IBOutlet weak var GoalImage: UIImageView!
    @IBOutlet weak var GoalName: UILabel!
    @IBOutlet weak var TargetDate: UILabel!
    @IBOutlet weak var AcheivedAmount: UILabel!
    @IBOutlet weak var TotalAmount: UILabel!
    @IBOutlet weak var ToGoAmountLabel: UILabel!
    @IBOutlet weak var GoalProgressBar: UIProgressView!
    @IBOutlet weak var AddMoneyButton: UIButton!
    @IBOutlet weak var GoalEditButton: UIButton!

    @IBOutlet var imageEdit: UIButton!
    
    var onAddMoney: (() -> Void)?
    var onDetail:   (() -> Void)?
    var onImagePicked: ((UIImage) -> Void)?

    

    override func awakeFromNib() {
        super.awakeFromNib()
        applyStyle()
    }

    

    private func applyStyle() {
        contentView.backgroundColor    = AppColors.card

        GoalName.textColor             = AppColors.textPrimary

        TargetDate.textColor           = AppColors.textSecondary

        AcheivedAmount.textColor       = AppColors.textPrimary

        TotalAmount.textColor          = AppColors.textSecondary

        ToGoAmountLabel.textColor      = AppColors.textSecondary

        GoalProgressBar.progressTintColor = AppColors.brand
        GoalProgressBar.trackTintColor    = AppColors.brandLight
        GoalProgressBar.layer.cornerRadius = 3
        GoalProgressBar.clipsToBounds      = true
        GoalProgressBar.transform = GoalProgressBar.transform.scaledBy(x: 1, y: 3)

    }
    
    
      func presentPhotoPicker(from viewController: UIViewController) {
          var config = PHPickerConfiguration(photoLibrary: .shared())
          config.selectionLimit = 1
          config.filter         = .images

          let picker = PHPickerViewController(configuration: config)
          picker.delegate = self
          viewController.present(picker, animated: true)
      }

      func configure(with goal: Goal) {
          GoalName.text    = goal.name
          TargetDate.text  = "Target: \(formattedMonth(goal.targetDate))"

          let achieved     = formatCurrency(goal.currentlySaved)
          let total        = formatCurrency(goal.targetAmount)
          AcheivedAmount.text  = achieved
          TotalAmount.text     = "/ \(total)"
          ToGoAmountLabel.text = "\(formatCurrency(goal.amountToGo)) to go"

          GoalProgressBar.setProgress(goal.progress, animated: false)

                 if let url = goal.pickedImageURL,
                    let data = try? Data(contentsOf: url),
                    let img  = UIImage(data: data) {
                     GoalImage.image           = img
                     GoalImage.contentMode     = .scaleAspectFill
                     GoalImage.backgroundColor = .clear

                 } else if let imageName = goal.imageName,
                           let img = UIImage(named: imageName) {
                     GoalImage.image           = img
                     GoalImage.contentMode     = .scaleAspectFill
                     GoalImage.backgroundColor = .clear

                 } else {
                     let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .thin)
                     GoalImage.image = UIImage(systemName: goal.iconName, withConfiguration: config)?
                         .withTintColor(AppColors.textSecondary, renderingMode: .alwaysOriginal)
                     GoalImage.contentMode     = .center
                     GoalImage.backgroundColor = AppColors.sectionBackground
                 }
    }

    @IBAction func addMoneyButtonTapped(_ sender: UIButton) {
        onAddMoney?()
    }
    

    @IBAction func goalEditButtonTapped(_ sender: UIButton) {
        onDetail?()
    }
    

    
    @IBAction func imageEditTapped(_ sender: UIButton) {
        
        guard let vc = parentViewController else {return}
        presentPhotoPicker(from: vc)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let f             = NumberFormatter()
        f.numberStyle     = .currency
        f.currencyCode    = "INR"
        f.currencySymbol  = "₹"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "₹0"
    }

    private func formattedMonth(_ date: Date) -> String {
        let f        = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: date)
    }

}

extension OngoingGoalCollectionViewCell: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self, let image = object as? UIImage, error == nil else { return }
            DispatchQueue.main.async {
                self.GoalImage.image       = image
                self.GoalImage.contentMode = .scaleAspectFill
                self.onImagePicked?(image)
            }
        }
    }
}

private extension UIView {
    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
}
