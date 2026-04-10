import UIKit

class AboutUsViewController: UIViewController{

    @IBOutlet weak var yellowCircle: UIVisualEffectView!


    @IBOutlet weak var navigatior: UIPageControl!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var centerImage: UIImageView!
    @IBOutlet weak var greenCircle: UIVisualEffectView!
    private var currentPage = 0

    private let pages: [(title: String, info: String, image: String, buttonTitle: String, greenPos: CGPoint, yellowPos: CGPoint)] = [
        (
            title: "Track Every Expense",
            info: "See exactly where your money goes with our effortless categorization.",
            image: "Page 1",
            buttonTitle: "Continue",
            greenPos:  CGPoint(x: 1.0, y: 0.35),
            yellowPos: CGPoint(x: 0.0, y: 0.18)
        ),
        (
            title: "Manage Your Spending",
            info: "Stay on top of your financial goals with real time insights.",
            image: "Page 2",
            buttonTitle: "Continue",
            greenPos: CGPoint(x: 1.0, y: 0.3),
            yellowPos: CGPoint(x: 0.18, y: 0.23)
        ),
        (
            title: "Reach Your Goals",
            info: "From Daily expense to next big goal, we've got you covered.",
            image: "Page 3",
            buttonTitle: "Continue",
            greenPos: CGPoint(x: 1.0, y: 0.25),
            yellowPos: CGPoint(x: 0.0, y: 0.28)
        ),
        (
            title: "Your Financial Assistant",
            info: "Understand your spending and grow better habits every day.",
            image: "Page 4",
            buttonTitle: "Get Started",
            greenPos: CGPoint(x: 1.0, y: 0.2),
            yellowPos: CGPoint(x: 0.18, y: 0.33)
        )
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        yellowCircle.layer.cornerRadius = 120
        yellowCircle.clipsToBounds      = true
        greenCircle.layer.cornerRadius  = 180
        greenCircle.clipsToBounds       = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if currentPage == 0 {
            applyPage(at: 0, animated: false)
        }
    }

    // MARK: - Continue
    @IBAction func skipTapped(_ sender: Any) {
        navigateToNextFlow()
    }
    
    @IBAction func continueTapped(_ sender: Any) {
        guard currentPage < pages.count  else { return }
        currentPage += 1
        if(currentPage == 4){
            navigateToNextFlow()
        }else{
            applyPage(at: currentPage, animated: true)
            navigatior.currentPage = currentPage
        }
    }

    // MARK: - Apply Page
 
    private func navigateToNextFlow() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let identifier: String

        if DatabaseManager.shared.hasActiveSession {
            identifier = DatabaseManager.shared.isCurrentUserSetupComplete() ? "TabBar" : "GetInfo"
        } else {
            identifier = "SingInUp"
        }

        let vc = storyboard.instantiateViewController(withIdentifier: identifier)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate,
           let window = sceneDelegate.window {

            window.rootViewController = vc
            window.makeKeyAndVisible()

            let transition = CATransition()
            transition.duration = 0.5
            transition.type = .push
            transition.subtype = .fromRight
            window.layer.add(transition, forKey: kCATransition)
        }
    }
    
    private func applyPage(at index: Int, animated: Bool) {
        let page         = pages[index]
        let screenWidth  = view.bounds.width
        let screenHeight = view.bounds.height

        let greenTarget  = CGPoint(
            x: screenWidth  * page.greenPos.x,
            y: screenHeight * page.greenPos.y
        )
        let yellowTarget = CGPoint(
            x: screenWidth  * page.yellowPos.x,
            y: screenHeight * page.yellowPos.y
        )

        if animated {
            // Circles spring smoothly from current position to next
            UIView.animate(
                withDuration: 0.7,
                delay: 0,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.2,
                options: .curveEaseInOut
            ) {
                self.greenCircle.center  = greenTarget
                self.yellowCircle.center = yellowTarget
            }

            // Content fades out → updates → fades in
            UIView.animate(withDuration: 0.15) {
                self.titleLabel.alpha  = 0
                self.infoLabel.alpha   = 0
                self.centerImage.alpha = 0
                self.continueButton.alpha = 0
            } completion: { _ in
                self.titleLabel.text  = page.title
                self.infoLabel.text   = page.info
                self.centerImage.image = UIImage(named: page.image)
                self.continueButton.setTitle(page.buttonTitle, for: .normal)

                UIView.animate(withDuration: 0.25) {
                    self.titleLabel.alpha  = 1
                    self.infoLabel.alpha   = 1
                    self.centerImage.alpha = 1
                    self.continueButton.alpha = 1
                }
            }

        } else {
            greenCircle.center     = greenTarget
            yellowCircle.center    = yellowTarget
            titleLabel.text        = page.title
            infoLabel.text         = page.info
            centerImage.image      = UIImage(named: page.image)
            continueButton.setTitle(page.buttonTitle, for: .normal)
        }
    }
}
