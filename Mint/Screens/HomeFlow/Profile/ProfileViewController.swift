import UIKit
import UserNotifications

class ProfileViewController: UIViewController {

    @IBOutlet weak var LogoutButton: UIButton!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userEmailLabel: UILabel!
    @IBOutlet weak var notificationSwitch: UISwitch!
    @IBOutlet weak var backupSwitch: UISwitch!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
        let currentUser = DatabaseManager.shared.fetchCurrentUser()
        userNameLabel.text = currentUser?.name ?? "Guest"
        userEmailLabel.text = currentUser?.email ?? "Sign in to continue"

        // Sync backup switch state
        backupSwitch.isOn = UserDefaults.standard.bool(forKey: "isBackupEnabled")

        // Sync notification switch state
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationSwitch.isOn = settings.authorizationStatus == .authorized
            }
        }
    }

    @IBAction func notificationButton(_ sender: UISwitch) {
        if sender.isOn {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    if !granted {
                        sender.setOn(false, animated: true)
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
        } else {
            showAlert(title: "Notifications", message: "To fully disable notifications, go to Settings.")
        }
    }

    @IBAction func backupEnabled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "isBackupEnabled")
        let status = sender.isOn ? "Backup enabled." : "Backup disabled."
        showAlert(title: "Backup", message: status)
    }

    // MARK: - Helper
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @IBAction func LogoutButton(_ sender: Any) {
        DatabaseManager.shared.signOut()

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SingInUp")

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = vc
            window.makeKeyAndVisible()

            UIView.transition(with: window,
                              duration: 0.3,
                              options: .transitionCrossDissolve,
                              animations: nil)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
