import UIKit

class SplashViewController: UIViewController {

    private let gradientLayer = CAGradientLayer()
    private let logo = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(hex: "#641AEF")
        configureGradient()
        configureLogo()
        animateSplash()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func configureGradient() {
        gradientLayer.colors = [
            UIColor(hex: "#641AEF").cgColor,
            UIColor(hex: "#9428FF").cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func configureLogo() {
        logo.image = UIImage(named: "App") ?? UIImage(named: "logo")
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.contentMode = .scaleAspectFit
        logo.layer.cornerRadius = 14
        logo.clipsToBounds = true

        view.addSubview(logo)

        NSLayoutConstraint.activate([
            logo.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 120),
            logo.heightAnchor.constraint(equalToConstant: 120)
        ])

        logo.alpha = 0
        logo.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
    }

    private func animateSplash() {
        UIView.animate(withDuration: 0.75,
                       delay: 0.1,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0.5,
                       options: .curveEaseOut) {

            self.logo.alpha = 1
            self.logo.transform = .identity

        } completion: { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.fadeOutLogo()
            }
        }
    }

    private func fadeOutLogo() {
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
            self.logo.alpha = 0
            self.logo.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        } completion: { [weak self] _ in
            self?.goToMainApp()
        }
    }

    private func goToMainApp() {
        guard let window = view.window else { return }
        let nextViewController = AppFlowManager.mainFlowViewController()
        let splashSnapshot = view.snapshotView(afterScreenUpdates: false)

        window.rootViewController = nextViewController

        guard let splashSnapshot else { return }
        splashSnapshot.frame = window.bounds
        window.addSubview(splashSnapshot)

        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
            splashSnapshot.alpha = 0
        } completion: { _ in
            splashSnapshot.removeFromSuperview()
        }
    }
}
