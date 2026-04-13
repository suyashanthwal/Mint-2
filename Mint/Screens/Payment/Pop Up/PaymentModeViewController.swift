
import UIKit

class PaymentModeViewController: UIViewController, UIGestureRecognizerDelegate {
    
    private enum SegueIdentifier {
        static let entryToManual = "EntryToManual"
        static let entryToScanner = "EntryToScanner"
        static let entryToReceipt = "EntryToReceipt"
    }

    @IBOutlet var CardViews: [UIView]!
    
    
    @IBOutlet var IconView: [UIView]!
    
    @IBOutlet var IconImageView: [UIImageView]!
    
    @IBOutlet var ChevronButton: [UIButton]!
    
    @IBOutlet var InsideIconView: [UIView]!
    
    @IBOutlet var InsideIconImageView: [UIImageView]!
    
    @IBOutlet var AllPrimaryText: [UILabel]!
    
    @IBOutlet var AllSecondaryText: [UILabel]!
    
    
    @IBAction func DismissButtonTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let sheet = self.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        setupUI()
    }
    
        @IBAction func manualEntryButton(_ sender: Any) {
            performSegue(withIdentifier: SegueIdentifier.entryToManual, sender: self)
        }
    
  
        
        @IBAction func scanQrButton(_ sender: Any) {
            performSegue(withIdentifier: SegueIdentifier.entryToScanner, sender: self)
        }
        
        @IBAction func scanReceiptButton(_ sender: Any) {
            performSegue(withIdentifier: SegueIdentifier.entryToReceipt, sender: self)
        }
        
        override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == SegueIdentifier.entryToManual {
                segue.destination.modalPresentationStyle = .fullScreen
            } else if segue.identifier == SegueIdentifier.entryToScanner {
                segue.destination.modalPresentationStyle = .fullScreen
            } else if segue.identifier == SegueIdentifier.entryToReceipt {
                segue.destination.modalPresentationStyle = .fullScreen
            }
        }
        
        func setupUI() {
            view.backgroundColor = AppColors.background
            
            for (index, cview) in CardViews.enumerated() {
                cview.backgroundColor = AppColors.sectionBackground
                cview.layer.cornerRadius = 12
                cview.tag = index
                cview.isUserInteractionEnabled = true
                let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
                tap.delegate = self
                cview.addGestureRecognizer(tap)
            }
            
            for (index, eachbutton) in ChevronButton.enumerated() {
                eachbutton.tintColor = AppColors.textSecondary
                eachbutton.tag = index
            }
            
            for iconview in InsideIconView {
                iconview.backgroundColor = AppColors.card
                iconview.layer.cornerRadius = 20
                iconview.clipsToBounds = true
            }
            
            for imageview in InsideIconImageView {
                imageview.tintColor = AppColors.brand
            }
        }
        
        @objc func cardTapped(_ sender: UITapGestureRecognizer) {
            guard let tappedCard = sender.view else { return }
            selectCard(at: tappedCard.tag)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.performSegueForCard(at: tappedCard.tag)
            }
        }

        func selectCard(at index: Int) {
            for (i, cview) in CardViews.enumerated() {
                cview.backgroundColor = AppColors.sectionBackground
                if i < InsideIconView.count {
                    InsideIconView[i].backgroundColor = AppColors.card
                }
                if i < InsideIconImageView.count {
                    InsideIconImageView[i].tintColor = AppColors.brand
                }
            }

            guard index < CardViews.count else { return }
            UIView.animate(withDuration: 0.2) {
                self.CardViews[index].backgroundColor = AppColors.brandLight
                if index < self.InsideIconView.count {
                    self.InsideIconView[index].backgroundColor = AppColors.brand
                }
                if index < self.InsideIconImageView.count {
                    self.InsideIconImageView[index].tintColor = AppColors.brandText
                }
            }
        }

        private func performSegueForCard(at index: Int) {
            switch index {
            case 0:
                performSegue(withIdentifier: SegueIdentifier.entryToManual, sender: self)
            case 1:
                performSegue(withIdentifier: SegueIdentifier.entryToScanner, sender: self)
            case 2:
                performSegue(withIdentifier: SegueIdentifier.entryToReceipt, sender: self)
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var currentView: UIView? = touch.view
            while let view = currentView {
                if view is UIControl {
                    return false
                }
                currentView = view.superview
            }
            return true
        }
    }
