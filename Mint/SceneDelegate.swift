
import AuthenticationServices
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        _ = DatabaseManager.shared
        BillSubscriptionReminderManager.shared.refreshAllReminders()
        guard let windowScene = (scene as? UIWindowScene) else { return }

            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = AppFlowManager.initialViewController()
            self.window = window
            window.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        validateAppleCredentialIfNeeded()
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }

    private func validateAppleCredentialIfNeeded() {
        guard DatabaseManager.shared.currentAuthenticationProvider == .apple,
              let appleUserIdentifier = DatabaseManager.shared.currentAppleUserIdentifier
        else { return }

        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserIdentifier) { [weak self] state, error in
            guard error == nil else { return }
            guard state != .authorized else { return }

            DispatchQueue.main.async {
                DatabaseManager.shared.signOut()
                self?.window?.rootViewController = AppFlowManager.initialViewController()
                self?.window?.makeKeyAndVisible()
            }
        }
    }

}
