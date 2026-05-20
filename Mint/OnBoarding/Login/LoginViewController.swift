
import AuthenticationServices
import UIKit

class LoginViewController: UIViewController {

    private static let applePromptShownKey = "apple_sign_in_prompt_shown"

    @IBOutlet weak var signInView: UIView!
    @IBOutlet weak var signUpView: UIView!

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!

    @IBOutlet weak var signUpEmailTextField: UITextField!
    @IBOutlet weak var signUpPasswordTextField: UITextField!
    @IBOutlet weak var signUpConfirmPasswordTextField: UITextField!
    private var hasPresentedApplePromptThisSession = false
    private var hasAppliedFieldRenderingCleanup = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        enableKeyboardDismissOnBackgroundTapAndSwipe()
        setupUI()

        signInView.alpha = 1
        signInView.transform = .identity

        signUpView.transform = CGAffineTransform(translationX: -view.frame.width, y: 0)
        signUpView.alpha = 0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentAppleSignInPromptIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // UITextField may recreate internal subviews after viewDidLoad,
        // so we re-apply the transparency cleanup once layout has settled.
        if !hasAppliedFieldRenderingCleanup {
            hasAppliedFieldRenderingCleanup = true
            refreshFieldRendering()
        }
    }
    @IBAction func goToSignUp(_ sender: Any) {
        signUpView.transform = CGAffineTransform(translationX: -view.frame.width, y: 0)
        signUpView.alpha = 1

        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
            self.signInView.transform = CGAffineTransform(translationX: self.view.frame.width, y: 0)
            self.signInView.alpha = 0

            self.signUpView.transform = .identity
        }
    }

    @IBAction func goToSignIn(_ sender: Any) {
        signInView.transform = CGAffineTransform(translationX: view.frame.width, y: 0)
        signInView.alpha = 1

        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
            self.signUpView.transform = CGAffineTransform(translationX: -self.view.frame.width, y: 0)
            self.signUpView.alpha = 0

            self.signInView.transform = .identity
        }
    }

    @IBAction func loginTapped(_ sender: Any) {
        let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordTextField.text ?? ""

        guard isValidEmail(email), !password.isEmpty else {
            showAlert(title: "Missing Information", message: "Enter a valid email and password to sign in.")
            return
        }

        guard DatabaseManager.shared.signIn(email: email, password: password) else {
            showAlert(title: "Sign In Failed", message: "We couldn't find an account with those credentials.")
            return
        }

        let destination = DatabaseManager.shared.isCurrentUserSetupComplete() ? "TabBar" : "GetInfo"
        switchRootViewController(identifier: destination)
    }
        
    @IBAction func signUpTapped(_ sender: Any) {
        let email = signUpEmailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = signUpPasswordTextField.text ?? ""
        let confirmPassword = signUpConfirmPasswordTextField.text ?? ""

        guard isValidEmail(email) else {
            showAlert(title: "Invalid Email", message: "Enter a valid email address to create your account.")
            return
        }

        guard !password.isEmpty else {
            showAlert(title: "Missing Password", message: "Enter a password for your new account.")
            return
        }

        guard password == confirmPassword else {
            showAlert(title: "Passwords Don’t Match", message: "Re-enter the same password to continue.")
            return
        }

        guard DatabaseManager.shared.createUserAccount(email: email, password: password) != nil else {
            showAlert(title: "Account Exists", message: "An account with this email already exists.")
            return
        }

        switchRootViewController(identifier: "OnboardingNav")
    }

    @IBAction func appleSignInTapped(_ sender: Any) {
        beginAppleSignIn()
    }

    private func isValidEmail(_ email: String) -> Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }

    private func presentAppleSignInPromptIfNeeded() {
        guard !DatabaseManager.shared.hasActiveSession,
              !hasPresentedApplePromptThisSession,
              !UserDefaults.standard.bool(forKey: Self.applePromptShownKey)
        else { return }

        hasPresentedApplePromptThisSession = true
        UserDefaults.standard.set(true, forKey: Self.applePromptShownKey)

        let alert = UIAlertController(
            title: "Sign in with Apple?",
            message: "You can create your Mint account faster with your Apple ID, or keep using email and password.",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Continue with Apple", style: .default) { [weak self] _ in
            self?.beginAppleSignIn()
        })
        alert.addAction(UIAlertAction(title: "Use Email Instead", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 40, width: 1, height: 1)
        }

        present(alert, animated: true)
    }

    private func beginAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func switchRootViewController(identifier: String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: identifier)

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

    private func setupUI() {
        view.backgroundColor = AppColors.background
        signInView.backgroundColor = AppColors.background
        signUpView.backgroundColor = AppColors.background

        passwordTextField.isSecureTextEntry = true
        signUpPasswordTextField.isSecureTextEntry = true
        signUpConfirmPasswordTextField.isSecureTextEntry = true

        styleFieldBackgroundViews()
        stylePrimaryButtons()
        styleLabels()
        styleButtons()
        styleDecorativeViews()
    }

    private func styleFieldBackgroundViews() {
        refreshFieldRendering()

        let passwordToggleButtons = view.allSubviews.compactMap { $0 as? UIButton }.filter {
            $0.superview?.subviews.contains(where: { $0 is UITextField }) == true
        }

        for button in passwordToggleButtons {
            if var config = button.configuration {
                config.baseBackgroundColor = .clear
                config.baseForegroundColor = AppColors.textSecondary
                config.background.backgroundColor = .clear
                config.background.strokeColor = .clear
                config.background.strokeWidth = 0
                button.configuration = config
            }
            button.backgroundColor = .clear
            button.tintColor = AppColors.textSecondary
        }

        let fieldContainerViews = [
            emailTextField.superview,
            passwordTextField.superview,
            signUpEmailTextField.superview,
            signUpPasswordTextField.superview,
            signUpConfirmPasswordTextField.superview
        ].compactMap { $0 }

        for containerView in Set(fieldContainerViews.map { ObjectIdentifier($0) }).compactMap({ identifier in
            fieldContainerViews.first(where: { ObjectIdentifier($0) == identifier })
        }) {
            containerView.backgroundColor = AppColors.inputBackground
            containerView.layer.cornerRadius = 18
            containerView.layer.borderWidth = 1
            containerView.layer.borderColor = AppColors.cardBorder.cgColor
            containerView.clipsToBounds = true
        }
    }

    private func refreshFieldRendering() {
        let textFields = [
            emailTextField,
            passwordTextField,
            signUpEmailTextField,
            signUpPasswordTextField,
            signUpConfirmPasswordTextField
        ]

        for textField in textFields {
            textField?.backgroundColor = .clear
            textField?.layer.backgroundColor = UIColor.clear.cgColor
            textField?.borderStyle = .none
            textField?.clipsToBounds = false
            textField?.textColor = AppColors.textPrimary
            textField?.tintColor = AppColors.textPrimary

            if let textField {
                clearBackgroundRecursively(in: textField)
                textField.subviews.forEach { clearBackgroundRecursively(in: $0) }
                textField.attributedPlaceholder = NSAttributedString(
                    string: textField.placeholder ?? "",
                    attributes: [
                        .foregroundColor: AppColors.textSecondary.withAlphaComponent(0.45),
                        .font: textField.font as Any
                    ]
                )
            }
        }
    }

    private func stylePrimaryButtons() {
        for button in primaryAuthButtons() {
            button.superview?.backgroundColor = AppColors.brand
            button.superview?.layer.cornerRadius = 18
            button.superview?.clipsToBounds = true

            var config = button.configuration ?? .plain()
            config.baseBackgroundColor = .clear
            config.baseForegroundColor = AppColors.brandText
            button.configuration = config
            button.tintColor = AppColors.brandText
            button.titleLabel?.font = MintFont.space(size: 17, weight: .bold)
        }
    }

    private func clearBackgroundRecursively(in view: UIView) {
        view.backgroundColor = .clear
        view.isOpaque = false
        view.layer.backgroundColor = UIColor.clear.cgColor

        for subview in view.subviews {
            clearBackgroundRecursively(in: subview)
        }
    }

    private func styleLabels() {
        for label in view.allSubviews.compactMap({ $0 as? UILabel }) {
            switch label.text {
            case "Sign In", "Sign Up":
                label.font = MintFont.syne(size: 32, weight: .bold)
                label.textColor = AppColors.textPrimary
            case "Continue your journey to financial clarity":
                label.font = MintFont.space(size: 16, weight: .medium)
                label.textColor = AppColors.textSecondary
            case "Email Address", "Password", "Confirm Password":
                label.font = MintFont.space(size: 14, weight: .bold)
                label.textColor = AppColors.textPrimary
            case "OR CONTINUE WITH":
                label.font = MintFont.space(size: 12, weight: .bold)
                label.textColor = AppColors.textSecondary
            case "Don't have an account?", "Already have an account?":
                label.font = MintFont.space(size: 15, weight: .medium)
                label.textColor = AppColors.textSecondary
            default:
                label.font = MintFont.space(size: label.font.pointSize, weight: MintFont.weight(for: label.font))
                if label.textColor == nil || label.textColor == .black {
                    label.textColor = AppColors.textPrimary
                }
            }

            label.removeCharacterSpacing()
        }
    }

    private func styleButtons() {
        for button in view.allSubviews.compactMap({ $0 as? UIButton }) {
            switch button.currentTitle {
            case "Sign In", "Sign Up":
                if primaryAuthButtons().contains(where: { $0 === button }) {
                    continue
                }
                applyAccentTextButtonStyle(button)
            case "Forgot Password?":
                applyAccentTextButtonStyle(button)
            default:
                break
            }
        }
    }

    private func applyAccentTextButtonStyle(_ button: UIButton) {
        button.superview?.backgroundColor = .clear
        button.superview?.layer.cornerRadius = 0
        button.superview?.layer.borderWidth = 0
        button.superview?.layer.borderColor = UIColor.clear.cgColor

        var config = button.configuration ?? .plain()
        config.baseBackgroundColor = .clear
        config.baseForegroundColor = AppColors.accent
        config.background.backgroundColor = .clear
        config.background.strokeColor = .clear
        config.background.strokeWidth = 0
        button.configuration = config
        button.backgroundColor = .clear
        button.tintColor = AppColors.accent
        button.titleLabel?.font = MintFont.space(size: button.titleLabel?.font.pointSize ?? 15, weight: .semibold)
    }

    private func primaryAuthButtons() -> [UIButton] {
        view.allSubviews
            .compactMap { $0 as? UIButton }
            .filter { button in
                button === loginButton
                    || button.actions(forTarget: self, forControlEvent: .touchUpInside)?.contains("loginTapped:") == true
                    || button.actions(forTarget: self, forControlEvent: .touchUpInside)?.contains("signUpTapped:") == true
            }
    }

    private func styleDecorativeViews() {
        for decorativeView in view.allSubviews where decorativeView.bounds.height <= 2 {
            decorativeView.backgroundColor = AppColors.cardBorder.withAlphaComponent(0.7)
        }

        if let logoContainer = view.allSubviews.first(where: {
            $0.subviews.contains(where: { ($0 as? UIImageView) != nil }) && $0.bounds.width == 56 && $0.bounds.height == 56
        }) {
            logoContainer.backgroundColor = AppColors.brandLight
            logoContainer.layer.cornerRadius = 18
            logoContainer.layer.borderWidth = 1
            logoContainer.layer.borderColor = AppColors.cardBorder.cgColor
            logoContainer.subviews.compactMap { $0 as? UIImageView }.forEach {
                $0.tintColor = AppColors.textPrimary
            }
        }
    }
}

extension LoginViewController: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            showAlert(title: "Apple Sign In Failed", message: "We couldn't read your Apple ID credential.")
            return
        }

        guard DatabaseManager.shared.signInWithApple(
            userIdentifier: credential.user,
            email: credential.email,
            fullName: credential.fullName
        ) != nil else {
            showAlert(title: "Apple Sign In Failed", message: "We couldn't create or restore your Mint account.")
            return
        }

        let destination = DatabaseManager.shared.isCurrentUserSetupComplete() ? "TabBar" : "GetInfo"
        switchRootViewController(identifier: destination)
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        let authorizationError = error as? ASAuthorizationError
        guard authorizationError?.code != .canceled else { return }
        showAlert(title: "Apple Sign In Failed", message: error.localizedDescription)
    }
}

extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = view.window {
            return window
        }

        if let fallbackWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first {
            return fallbackWindow
        }

        preconditionFailure("No presentation anchor available for Apple Sign In.")
    }
}
