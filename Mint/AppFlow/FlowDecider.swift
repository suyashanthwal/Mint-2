import UIKit

class AppFlowManager {

    static func initialViewController() -> UIViewController {
        SplashViewController()
    }

    static func mainFlowViewController() -> UIViewController {

        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        if DatabaseManager.shared.hasActiveSession {
            if DatabaseManager.shared.isCurrentUserSetupComplete() {
                return storyboard.instantiateViewController(withIdentifier: "TabBar")
            }
            return storyboard.instantiateViewController(withIdentifier: "GetInfo")
        } else {
            return storyboard.instantiateViewController(withIdentifier: "SingInUp")
        }
    }
}
