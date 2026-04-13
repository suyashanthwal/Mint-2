
import UIKit

class ProfileViewController: UIViewController {

    @IBOutlet weak var LogoutButton: UIButton!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userEmailLabel: UILabel!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
        let currentUser = DatabaseManager.shared.fetchCurrentUser()
        userNameLabel.text = currentUser?.name ?? "Guest"
        userEmailLabel.text = currentUser?.email ?? "Sign in to continue"
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
