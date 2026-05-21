import PhotosUI
import UIKit

protocol EditProfileViewControllerDelegate: AnyObject {
    func editProfileViewControllerDidSaveProfile(_ viewController: EditProfileViewController)
}

final class EditProfileViewController: UIViewController {

    @IBOutlet weak var dimmedBackgroundView: UIView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var photoButton: UIButton!
    @IBOutlet weak var nameFieldContainerView: UIView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!

    weak var delegate: EditProfileViewControllerDelegate?

    private var selectedImage: UIImage?
    private var existingProfileImageName: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTheme()
        loadCurrentProfile()
    }

    @IBAction func closeTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction func changePhotoTapped(_ sender: UIButton) {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @IBAction func saveTapped(_ sender: UIButton) {
        guard let name = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else {
            showAlert(title: "Name Required", message: "Please enter your name before saving.")
            return
        }

        var updatedImageName = existingProfileImageName

        if let selectedImage {
            guard let savedImageName = ProfileImageStore.save(image: selectedImage) else {
                showAlert(title: "Photo Error", message: "We couldn't save your new profile photo.")
                return
            }
            updatedImageName = savedImageName
        }

        guard DatabaseManager.shared.updateCurrentUserProfile(name: name, profileImageName: updatedImageName) else {
            if updatedImageName != existingProfileImageName {
                ProfileImageStore.deleteImage(named: updatedImageName)
            }
            showAlert(title: "Save Failed", message: "We couldn't update your profile right now.")
            return
        }

        if updatedImageName != existingProfileImageName {
            ProfileImageStore.deleteImage(named: existingProfileImageName)
        }

        if ICloudBackupService.shared.isBackupEnabled, ICloudBackupService.shared.canUseBackupForCurrentUser() {
            try? ICloudBackupService.shared.syncCurrentUserBackup()
        }

        delegate?.editProfileViewControllerDidSaveProfile(self)
        dismiss(animated: true)
    }

    private func configureTheme() {
        view.backgroundColor = .clear
        dimmedBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.45)

        cardView.backgroundColor = AppColors.card
        cardView.layer.cornerRadius = 28
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = AppColors.cardBorder.withAlphaComponent(0.8).cgColor

        titleLabel.font = MintFont.syne(size: 28, weight: .bold)
        titleLabel.textColor = AppColors.textPrimary

        subtitleLabel.font = MintFont.space(size: 15, weight: .medium)
        subtitleLabel.textColor = AppColors.textSecondary

        profileImageView.layer.cornerRadius = 54
        profileImageView.layer.borderWidth = 1.5
        profileImageView.layer.borderColor = AppColors.cardBorder.cgColor
        profileImageView.clipsToBounds = true
        profileImageView.backgroundColor = AppColors.inputBackground
        profileImageView.tintColor = AppColors.textPrimary
        profileImageView.contentMode = .scaleAspectFill

        photoButton.setTitleColor(AppColors.accent, for: .normal)
        photoButton.titleLabel?.font = MintFont.space(size: 15, weight: .semibold)
        photoButton.tintColor = AppColors.accent

        nameFieldContainerView.backgroundColor = AppColors.inputBackground
        nameFieldContainerView.layer.cornerRadius = 18
        nameFieldContainerView.layer.borderWidth = 1
        nameFieldContainerView.layer.borderColor = AppColors.cardBorder.cgColor

        nameTextField.font = MintFont.space(size: 17, weight: .medium)
        nameTextField.textColor = AppColors.textPrimary
        nameTextField.tintColor = AppColors.textPrimary
        nameTextField.backgroundColor = .clear
        nameTextField.attributedPlaceholder = NSAttributedString(
            string: "Your name",
            attributes: [
                .foregroundColor: AppColors.textSecondary.withAlphaComponent(0.6),
                .font: MintFont.space(size: 17, weight: .medium)
            ]
        )

        cancelButton.setTitleColor(AppColors.textSecondary, for: .normal)
        cancelButton.titleLabel?.font = MintFont.space(size: 16, weight: .semibold)

        saveButton.applyPrimaryOnboardingStyle()
        saveButton.titleLabel?.font = MintFont.space(size: 17, weight: .bold)
    }

    private func loadCurrentProfile() {
        guard let user = DatabaseManager.shared.fetchCurrentUser() else { return }
        nameTextField.text = user.name
        existingProfileImageName = user.profileImageName
        applyProfileImage(ProfileImageStore.loadImage(named: user.profileImageName))
    }

    private func applyProfileImage(_ image: UIImage?) {
        if let image {
            profileImageView.image = image
            profileImageView.contentMode = .scaleAspectFill
        } else {
            profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
            profileImageView.contentMode = .scaleAspectFit
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        alert.overrideUserInterfaceStyle = .dark
        present(alert, animated: true)
    }
}

extension EditProfileViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self)
        else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async {
                guard let self, let image = object as? UIImage else { return }
                self.selectedImage = image
                self.applyProfileImage(image)
            }
        }
    }
}
