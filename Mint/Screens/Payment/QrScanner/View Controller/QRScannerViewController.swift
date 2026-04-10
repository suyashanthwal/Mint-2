//
//  QRScannerViewController.swift
//  QrScanner
//
//  Created by Ayush Singh Bhandari on 12/02/26.
//

import UIKit
import AVFoundation
import Combine
import PhotosUI //for PHPickerViewController
import CoreImage

class QRScannerViewController: UIViewController {
    
    
    @IBOutlet weak var qrContainerView: UIView!
    @IBOutlet weak var cameraPreviewView: UIView!
    @IBOutlet weak var scannerBoxView: ScannerBoxView!
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var buttonStackView: UIStackView!
    @IBOutlet weak var uploadButton: UIButton!

  
    

    private let viewModel = QRCodeScannerViewModel()
        private var cancellables = Set<AnyCancellable>()

        /// Camera session used for QR scanning
        private var captureSession: AVCaptureSession?

        /// Preview layer shown on screen
        private var previewLayer: AVCaptureVideoPreviewLayer?

        /// Haptic feedback when scan succeeds
        private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)


        

        override func viewDidLoad() {
            super.viewDidLoad()

            setupBindings()
            feedbackGenerator.prepare()

            checkCameraPermission()
           
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)

            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if captureSession != nil || cameraStatus == .authorized {
                checkCameraPermission()
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)

            // Stop camera when leaving screen
            stopCameraSession()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()

            // Update preview layer frame on layout changes
            previewLayer?.frame = cameraPreviewView.bounds
            updateOverlayMask()
        }
    @IBAction func cancelTapped(_ sender: Any) {
        presentingViewController?.presentingViewController?.dismiss(animated: true)
        //when clicked the x navbutton , it will close the qr scanner and the payment mode pop up and return to the home screen
    }
    

    

        // MARK: - Bindings

        /// Binds ViewModel outputs to UI updates
        private func setupBindings() {

            // Handle successful scan
            viewModel.$scannedData
                .receive(on: DispatchQueue.main)
                .sink { [weak self] data in
                    guard let data = data else { return }
                    self?.handleSuccessfulScan(data)
                }
                .store(in: &cancellables)

            // Handle errors
            viewModel.$errorMessage
                .receive(on: DispatchQueue.main)
                .sink { [weak self] message in
                    guard let message = message else { return }
                    self?.showError(message)
                }
                .store(in: &cancellables)
        }


        // MARK: - Camera Handling

        /// Checks and requests camera permission
        private func checkCameraPermission() {

            switch AVCaptureDevice.authorizationStatus(for: .video) {

            case .authorized:
                // Setup or resume camera
                if captureSession == nil {
                    setupCamera()
                } else {
                    startCameraSession()
                }

            case .notDetermined:
                // Ask user for permission
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        guard let self = self else { return }

                        if granted {
                            self.setupCamera()
                        } else {
                            self.showPermissionDeniedAlert()
                        }
                    }
                }

            case .denied, .restricted:
                showPermissionDeniedAlert()

            @unknown default:
                showPermissionDeniedAlert()
            }
        }

        /// Sets up camera session and preview layer
        private func setupCamera() {

            let session = AVCaptureSession()

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                showError("Unable to access camera")
                return
            }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()

            guard session.canAddOutput(output) else {
                showError("Cannot add output")
                return
            }

            session.addOutput(output)

            // Configure QR detection
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]

            captureSession = session

            // Setup preview layer
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = cameraPreviewView.bounds

            cameraPreviewView.layer.insertSublayer(preview, at: 0)
            previewLayer = preview

            // Start session in background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                session.startRunning()
                DispatchQueue.main.async {
                    self?.viewModel.startScanning()
                }
            }
        }

        /// Starts camera session if not running
        private func startCameraSession() {
            guard let session = captureSession, !session.isRunning else { return }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                session.startRunning()
                DispatchQueue.main.async {
                    self?.viewModel.startScanning()
                }
            }
        }

        /// Stops camera session if running
        private func stopCameraSession() {
            guard let session = captureSession, session.isRunning else { return }

            viewModel.stopScanning()

            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }


        

        /// Creates cut-out mask for scanner box UI
        private func updateOverlayMask() {

            guard overlayView.bounds != .zero else { return }

            let path = UIBezierPath(rect: overlayView.bounds)

            let cutout = UIBezierPath(
                roundedRect: scannerBoxView.frame,
                cornerRadius: 12
            )

            path.append(cutout)
            path.usesEvenOddFillRule = true

            let mask = CAShapeLayer()
            mask.path = path.cgPath
            mask.fillRule = .evenOdd

            overlayView.layer.mask = mask
        }

        /// Called when QR scan succeeds
        private func handleSuccessfulScan(_ data: UPIQRCodeData) {
            stopCameraSession()
            feedbackGenerator.impactOccurred()
            navigateToAmountScreen(with: data)
        }

        /// Navigates to amount screen after scan
        private func navigateToAmountScreen(with data: UPIQRCodeData) {

            let storyboard = UIStoryboard(name: "Main", bundle: nil)

            guard let nav = storyboard.instantiateViewController(
                withIdentifier: "AmountNavigationController"
            ) as? UINavigationController,
                  let vc = nav.viewControllers.first as? AmountViewController else { return }

            vc.upiData = data
            nav.modalPresentationStyle = .fullScreen

            present(nav, animated: true) { [weak self] in
                self?.viewModel.resetScanner()
            }
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

    private func processScannedImage(_ image: UIImage) {
        guard let qrString = extractQRCode(from: image) else {
            showError("No QR code was detected in the selected image.")
            return
        }

        _ = viewModel.parseUPIQRCode(qrString)
    }

    private func extractQRCode(from image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image),
              let detector = CIDetector(
                ofType: CIDetectorTypeQRCode,
                context: nil,
                options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
              ) else {
            return nil
        }

        let features = detector.features(in: ciImage)
        return features
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
            .first
    }


        // MARK: - Error Handling

        private func showError(_ message: String) {
            let alert = UIAlertController(title: "Error",
                                          message: message,
                                          preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }

        private func showPermissionDeniedAlert() {
            let alert = UIAlertController(
                title: "Camera Access Required",
                message: "Enable camera access in Settings.",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            })

            present(alert, animated: true)
        }
    }


    // MARK: - QR Delegate

    extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {

            guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  obj.type == .qr,
                  let value = obj.stringValue else { return }

            if viewModel.isScanning {
                _ = viewModel.parseUPIQRCode(value)
            }
        }
    }

extension QRScannerViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self,
                  let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    guard let self, let image = object as? UIImage else { return }
                    self.processScannedImage(image)
                }
            }
        }
    }
}


   
