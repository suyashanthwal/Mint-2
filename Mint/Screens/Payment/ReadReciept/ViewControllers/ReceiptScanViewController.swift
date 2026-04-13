import UIKit
import PhotosUI

class ReceiptScanViewController: UIViewController {

    @IBOutlet weak var uploadButton: UIButton!

    @IBAction func cancelTapped(_ sender: Any) {
        presentingViewController?.presentingViewController?.dismiss(animated: true)
    }

    @IBAction func uploadButtonTapped(_ sender: UIButton) {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .automatic

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        present(picker, animated: true)
    }
}

extension ReceiptScanViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    guard let self, let image = object as? UIImage else { return }
                    self.startReceiptScan(image: image)
                }
            }
        }
    }

    private func startReceiptScan(image: UIImage) {
        let hud = UIAlertController(title: "Scanning Receipt", message: "Analysing the Receipt", preferredStyle: .alert)
        present(hud, animated: true)

        ReceiptScanPipeline.shared.scan(image: image) { [weak self] result in
            guard let self else { return }
            self.dismiss(animated: true) {
                switch result {
                case .success(let scanData):
                    self.navigateToReceiptReview(scanData: scanData, image: image)
                case .failure(let error):
                    self.showError("Receipt scan failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func navigateToReceiptReview(scanData: ReceiptScanData, image: UIImage) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let reviewVC = storyboard.instantiateViewController(
            withIdentifier: "ReceiptReviewViewController"
        ) as? ReceiptReviewViewController else {
            showError("Could not load review screen.")
            return
        }

        let categories = DatabaseManager.shared.fetchCategories()
        let expenseCategories = categories.filter { $0.type == .expense }

        reviewVC.scanData = scanData
        reviewVC.receiptImage = image
        reviewVC.userCategories = expenseCategories.isEmpty ? categories : expenseCategories

        let nav = UINavigationController(rootViewController: reviewVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
