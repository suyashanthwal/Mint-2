import UIKit
import UserNotifications
import AuthenticationServices

final class ProfileViewController: UIViewController {

    @IBOutlet weak var LogoutButton: UIButton?
    @IBOutlet weak var userNameLabel: UILabel?
    @IBOutlet weak var userEmailLabel: UILabel?
    @IBOutlet weak var notificationSwitch: UISwitch?
    @IBOutlet weak var backupSwitch: UISwitch?

    private weak var profileImageView: UIImageView?
    private weak var profileCardView: UIView?
    private weak var settingsCardView: UIView?
    private weak var logoutContainerView: UIView?
    private weak var editProfileButton: UIButton?
    private weak var notificationsButton: UIButton?
    private weak var backupButton: UIButton?
    private weak var replayAppTourButton: UIButton?
    private weak var mainStackView: UIStackView?
    private var shouldEnableBackupAfterAppleLink = false

    override func viewDidLoad() {
        super.viewDidLoad()
        captureExistingStoryboardViews()
        configureTheme()
        refreshProfileUI()
        refreshNotificationState()
        refreshBackupState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureNavigationBar()
        refreshProfileUI()
        refreshNotificationState()
        refreshBackupState()
    }

    @IBAction func editProfileTapped(_ sender: UIButton) {
        guard let viewController = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "EditProfileViewController") as? EditProfileViewController
        else {
            showAlert(title: "Profile", message: "Edit Profile could not be opened right now.")
            return
        }
        

        viewController.modalPresentationStyle = .overFullScreen
        viewController.modalTransitionStyle = .crossDissolve
        viewController.delegate = self
        present(viewController, animated: true)
    }

    @IBAction func notificationButton(_ sender: UISwitch) {
        if sender.isOn {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        BillSubscriptionReminderManager.shared.refreshAllReminders()
                    } else {
                        sender.setOn(false, animated: true)
                        self.openSystemSettings()
                    }
                }
            }
        } else {
            BillSubscriptionReminderManager.shared.cancelAllManagedReminders()
            showAlert(title: "Notifications Off", message: "Bill and subscription reminders have been paused for Mint.")
        }
    }

    @IBAction func backupEnabled(_ sender: UISwitch) {
        guard sender.isOn else {
            ICloudBackupService.shared.setBackupEnabled(false)
            do {
                try ICloudBackupService.shared.removeBackupForCurrentUser()
            } catch {
                print("Backup removal failed: \(error)")
            }
            showAlert(title: "Backup Disabled", message: "Your iCloud sync snapshot has been turned off for this device.")
            return
        }

        guard DatabaseManager.shared.currentAuthenticationProvider == .apple else {
            sender.setOn(false, animated: true)
            presentAppleAccountRequiredAlert()
            return
        }

        enableBackupForCurrentAppleAccount()
    }

    @IBAction func replayAppTourTapped(_ sender: UIButton) {
        DatabaseManager.shared.resetOnboardingStateForCurrentUser()

        let alert = UIAlertController(
            title: "App Tour Reset",
            message: "Mint will reopen the main flow so you can see the in-app tour again.",
            preferredStyle: .alert
        )
        alert.overrideUserInterfaceStyle = .dark
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Replay", style: .default) { [weak self] _ in
            self?.restartAppFlow()
        })
        present(alert, animated: true)
    }

    @IBAction func logoutTapped(_ sender: UIButton) {
        performLogout()
    }

    @IBAction func LogoutButton(_ sender: Any) {
        performLogout()
    }

    private func performLogout() {
        DatabaseManager.shared.signOut()

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "SingInUp")

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else { return }

        window.rootViewController = viewController
        window.makeKeyAndVisible()

        UIView.transition(
            with: window,
            duration: 0.3,
            options: .transitionCrossDissolve,
            animations: nil
        )
    }

    private func configureTheme() {
        view.backgroundColor = AppColors.background
        let themedViews = [profileCardView, settingsCardView, logoutContainerView].compactMap { $0 }
        view.allSubviews.forEach { subview in
            if !themedViews.contains(where: { themedView in themedView === subview }) {
                subview.backgroundColor = .clear
            }
        }

        [profileCardView, settingsCardView, logoutContainerView].forEach {
            $0?.backgroundColor = AppColors.card
            $0?.layer.cornerRadius = 24
            $0?.layer.borderWidth = 1
            $0?.layer.borderColor = AppColors.cardBorder.withAlphaComponent(0.8).cgColor
        }

        profileImageView?.backgroundColor = AppColors.inputBackground
        profileImageView?.layer.cornerRadius = 40
        profileImageView?.layer.borderWidth = 1.5
        profileImageView?.layer.borderColor = AppColors.cardBorder.cgColor
        profileImageView?.clipsToBounds = true
        profileImageView?.tintColor = AppColors.textPrimary

        userNameLabel?.font = MintFont.syne(size: 28, weight: .bold)
        userNameLabel?.textColor = AppColors.textPrimary
        userEmailLabel?.font = MintFont.space(size: 15, weight: .medium)
        userEmailLabel?.textColor = AppColors.textSecondary

        configureSettingsButton(editProfileButton, title: "Edit Profile", icon: "person.crop.circle.badge.pencil")
        configureSettingsButton(notificationsButton, title: "Notifications", icon: "bell.badge")
        configureSettingsButton(backupButton, title: "Backup & Sync", icon: "icloud")
        configureSettingsButton(replayAppTourButton, title: "Replay App Tour", icon: "sparkles.rectangle.stack")
        applySettingsButtonColor(editProfileButton, color: AppColors.accent)
        styleSettingsCardContents()

        notificationSwitch?.onTintColor = AppColors.accent
        notificationSwitch?.thumbTintColor = AppColors.textPrimary
        backupSwitch?.onTintColor = AppColors.accent
        backupSwitch?.thumbTintColor = AppColors.textPrimary

        var logoutConfiguration = UIButton.Configuration.plain()
        logoutConfiguration.title = "Log Out"
        logoutConfiguration.image = UIImage(systemName: "power")
        logoutConfiguration.imagePadding = 10
        logoutConfiguration.baseForegroundColor = AppColors.error
        logoutConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
        LogoutButton?.configuration = logoutConfiguration
        LogoutButton?.titleLabel?.font = MintFont.space(size: 17, weight: .bold)
        LogoutButton?.contentHorizontalAlignment = .leading
        LogoutButton?.tintColor = AppColors.error
    }

    private func configureNavigationBar() {
        navigationController?.navigationBar.isHidden = false
        navigationController?.navigationBar.tintColor = AppColors.textPrimary
        navigationController?.navigationBar.barTintColor = AppColors.background
        navigationController?.navigationBar.backgroundColor = AppColors.background
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: AppColors.textPrimary,
            .font: MintFont.syne(size: 22, weight: .bold)
        ]
        navigationItem.title = "Profile"
    }

    private func refreshProfileUI() {
        let currentUser = DatabaseManager.shared.fetchCurrentUser()
        userNameLabel?.text = currentUser?.name ?? "Guest"
        userEmailLabel?.text = currentUser?.email ?? "Sign in to continue"

        if let image = ProfileImageStore.loadImage(named: currentUser?.profileImageName) {
            profileImageView?.image = image
            profileImageView?.contentMode = .scaleAspectFill
        } else {
            profileImageView?.image = UIImage(systemName: "person.crop.circle.fill")
            profileImageView?.contentMode = .scaleAspectFit
        }
    }

    private func refreshNotificationState() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationSwitch?.isOn = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
        }
    }

    private func refreshBackupState() {
        let canUseAppleBackup = DatabaseManager.shared.currentAuthenticationProvider == .apple
        backupSwitch?.isOn = canUseAppleBackup && ICloudBackupService.shared.isBackupEnabled
        backupSwitch?.isEnabled = true
        backupSwitch?.alpha = canUseAppleBackup ? 1 : 0.55
    }

    private func configureSettingsButton(_ button: UIButton?, title: String, icon: String) {
        guard let button else { return }
        var configuration = UIButton.Configuration.plain()
        var attributedTitle = AttributedString(title)
        attributedTitle.font = MintFont.space(size: 17, weight: .semibold)
        configuration.attributedTitle = attributedTitle
        configuration.image = UIImage(systemName: icon)
        configuration.imagePadding = 12
        configuration.baseForegroundColor = AppColors.textPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        configuration.background.backgroundColor = .clear
        button.configuration = configuration
        button.titleLabel?.font = MintFont.space(size: 17, weight: .semibold)
        button.contentHorizontalAlignment = .leading
        button.tintColor = AppColors.textPrimary
    }

    private func applySettingsButtonColor(_ button: UIButton?, color: UIColor) {
        guard let button,
              var configuration = button.configuration,
              let title = configuration.attributedTitle?.characters
        else { return }

        var attributedTitle = AttributedString(String(title))
        attributedTitle.font = MintFont.space(size: 17, weight: .semibold)
        attributedTitle.foregroundColor = color
        configuration.attributedTitle = attributedTitle
        configuration.baseForegroundColor = color
        button.configuration = configuration
        button.tintColor = color
    }

    private func captureExistingStoryboardViews() {
        mainStackView = view.allSubviews
            .compactMap { $0 as? UIStackView }
            .first { stackView in
                guard let logoutContainer = LogoutButton?.superview else { return false }
                return stackView.axis == .vertical && stackView.arrangedSubviews.contains { $0 === logoutContainer }
            }

        if let mainStackView, mainStackView.arrangedSubviews.count >= 3 {
            profileCardView = mainStackView.arrangedSubviews[0]
            settingsCardView = mainStackView.arrangedSubviews[1]
            logoutContainerView = mainStackView.arrangedSubviews[2]
        } else {
            profileCardView = userNameLabel?.closestSuperview(where: { $0.bounds.height >= 120 })
            settingsCardView = notificationSwitch?.closestSuperview(where: { $0.bounds.height >= 100 })
            logoutContainerView = LogoutButton?.superview
        }

        profileImageView = view.allSubviews
            .compactMap { $0 as? UIImageView }
            .first { $0.image != nil && $0.bounds.width <= 90 && $0.bounds.height <= 90 }

        let storyboardButtons = view.allSubviews.compactMap { $0 as? UIButton }
        editProfileButton = storyboardButtons.first { $0.configuration?.title == "Edit Profile" }
        replayAppTourButton = storyboardButtons.first { $0.configuration?.title == "Replay App Tour" }

        notificationsButton = rowButton(
            title: "Notifications",
            icon: "bell.badge",
            switchView: notificationSwitch
        )
        backupButton = rowButton(
            title: "Backup & Sync",
            icon: "icloud",
            switchView: backupSwitch
        )
    }

    private func styleSettingsCardContents() {
        settingsCardView?.allSubviews.compactMap { $0 as? UILabel }.forEach {
            $0.font = MintFont.space(size: 17, weight: .semibold)
            $0.textColor = AppColors.textPrimary
            if $0.text == "Backup & restore" {
                $0.text = "Backup & Sync"
            }
        }

        settingsCardView?.allSubviews.compactMap { $0 as? UIImageView }.forEach {
            $0.tintColor = AppColors.accent
        }
    }

    private func rowButton(title: String, icon: String, switchView: UISwitch?) -> UIButton {
        let button = UIButton(type: .system)
        button.isUserInteractionEnabled = false
        button.backgroundColor = .clear
        button.translatesAutoresizingMaskIntoConstraints = false
        configureSettingsButton(button, title: title, icon: icon)

        if let row = switchView?.closestSuperview(where: { $0.bounds.height >= 50 && $0 is UIStackView }) as? UIStackView,
           let label = row.arrangedSubviews.compactMap({ $0 as? UILabel }).first {
            label.text = title
            label.font = MintFont.space(size: 17, weight: .semibold)
            label.textColor = AppColors.textPrimary
        }

        return button
    }

    private func restartAppFlow() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else { return }

        window.rootViewController = AppFlowManager.initialViewController()
        window.makeKeyAndVisible()

        UIView.transition(
            with: window,
            duration: 0.3,
            options: .transitionCrossDissolve,
            animations: nil
        )
    }

    private func presentAppleAccountRequiredAlert() {
        let alert = UIAlertController(
            title: "Apple Sign In Required",
            message: "Connect your Apple ID to store Mint data in iCloud and restore it after reinstalling.",
            preferredStyle: .alert
        )
        alert.overrideUserInterfaceStyle = .dark
        alert.addAction(UIAlertAction(title: "Add Apple Account", style: .default) { [weak self] _ in
            self?.shouldEnableBackupAfterAppleLink = true
            self?.beginAppleAccountLinking()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func beginAppleAccountLinking() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func enableBackupForCurrentAppleAccount() {
        do {
            ICloudBackupService.shared.setBackupEnabled(true)
            try ICloudBackupService.shared.syncCurrentUserBackup()
            backupSwitch?.setOn(true, animated: true)
            showAlert(title: "Backup Enabled", message: "Mint will now sync your data to iCloud so you can restore it after reinstalling.")
        } catch {
            ICloudBackupService.shared.setBackupEnabled(false)
            backupSwitch?.setOn(false, animated: true)
            showAlert(title: "Backup Unavailable", message: error.localizedDescription)
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.overrideUserInterfaceStyle = .dark
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension ProfileViewController: EditProfileViewControllerDelegate {
    func editProfileViewControllerDidSaveProfile(_ viewController: EditProfileViewController) {
        refreshProfileUI()
    }
}

extension ProfileViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            shouldEnableBackupAfterAppleLink = false
            showAlert(title: "Apple Account", message: "We couldn't read your Apple ID credential.")
            return
        }

        guard DatabaseManager.shared.linkCurrentUserToApple(
            userIdentifier: credential.user,
            email: credential.email,
            fullName: credential.fullName
        ) else {
            shouldEnableBackupAfterAppleLink = false
            showAlert(title: "Apple Account", message: "This Apple ID is already connected to another Mint account.")
            return
        }

        refreshBackupState()
        if shouldEnableBackupAfterAppleLink {
            shouldEnableBackupAfterAppleLink = false
            enableBackupForCurrentAppleAccount()
        } else {
            showAlert(title: "Apple Account Added", message: "Your Mint account is now connected to Apple.")
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        let authorizationError = error as? ASAuthorizationError
        shouldEnableBackupAfterAppleLink = false
        guard authorizationError?.code != .canceled else { return }
        showAlert(title: "Apple Account", message: error.localizedDescription)
    }
}

extension ProfileViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = view.window {
            return window
        }

        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return windowScene?.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private extension UIView {
    func closestSuperview(where predicate: (UIView) -> Bool) -> UIView? {
        var view = superview
        while let currentView = view {
            if predicate(currentView) {
                return currentView
            }
            view = currentView.superview
        }
        return nil
    }
}
