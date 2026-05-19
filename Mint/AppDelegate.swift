
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UIViewController.enableMintTypographySwizzle()
        configureGlobalTypographyAppearance()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    private func configureGlobalTypographyAppearance() {
        let navTitleFont = MintFont.space(size: 28, weight: .semibold)
        let tabFont = MintFont.space(size: 10, weight: .medium)
        let barButtonFont = MintFont.space(size: 17, weight: .semibold)

        let navigationBarAppearance = UINavigationBar.appearance()
        navigationBarAppearance.titleTextAttributes = [
            .font: navTitleFont
        ]
        navigationBarAppearance.largeTitleTextAttributes = [
            .font: navTitleFont
        ]

        let tabBarItemAppearance = UITabBarItem.appearance()
        tabBarItemAppearance.setTitleTextAttributes([.font: tabFont], for: .normal)
        tabBarItemAppearance.setTitleTextAttributes([.font: tabFont], for: .selected)

        let barButtonItemAppearance = UIBarButtonItem.appearance()
        barButtonItemAppearance.setTitleTextAttributes([.font: barButtonFont], for: .normal)
        barButtonItemAppearance.setTitleTextAttributes([.font: barButtonFont], for: .highlighted)
        barButtonItemAppearance.setTitleTextAttributes([.font: barButtonFont], for: .disabled)
    }
}
