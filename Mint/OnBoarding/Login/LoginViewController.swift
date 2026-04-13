
import UIKit

class LoginViewController: UIViewController {

        
        @IBOutlet weak var signInView: UIView!
        @IBOutlet weak var signUpView: UIView!
        
        @IBOutlet weak var emailTextField: UITextField!
        @IBOutlet weak var passwordTextField: UITextField!
        @IBOutlet weak var loginButton: UIButton!
        
        @IBOutlet weak var signUpEmailTextField: UITextField!
        @IBOutlet weak var signUpPasswordTextField: UITextField!
        @IBOutlet weak var signUpConfirmPasswordTextField: UITextField!
        @IBOutlet weak var signUpButton: UIButton!

        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
    }
    
        override func viewDidLoad() {
            super.viewDidLoad()
            enableKeyboardDismissOnBackgroundTapAndSwipe()

                signInView.alpha = 1
                signInView.transform = .identity

                signUpView.transform = CGAffineTransform(translationX: -view.frame.width, y: 0)
                signUpView.alpha = 0

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

    private func isValidEmail(_ email: String) -> Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
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
}
