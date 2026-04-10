import UIKit
import Vision
import os.log

final class ReceiptOCRService {
    
    static let shared = ReceiptOCRService()
    private init() {}
    
    private let logger = OSLog(subsystem: "com.example.QrAndReceiptReading", category: "ReceiptOCR")

    // Public API
    
    func recognizeText(in image: UIImage,
                       completion: @escaping (Result<String, ReceiptOCRError>) -> Void) {

        guard let cgImage = image.cgImage else {
            os_log(" OCR Error: No CGImage provided", log: self.logger, type: .error)
            DispatchQueue.main.async {
                completion(.failure(.noImageProvided))
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            os_log("Starting OCR processing for image", log: self.logger, type: .info)
            
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self = self else { return }
                
                if let error = error {
                    os_log("OCR Request Failed: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                    DispatchQueue.main.async {
                        completion(.failure(.ocrFailed(error.localizedDescription)))
                    }
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    os_log("OCR: No text observations found", log: self.logger, type: .error)
                    DispatchQueue.main.async {
                        completion(.failure(.noTextFound))
                    }
                    return
                }

                let lines = observations.compactMap {
                    $0.topCandidates(1).first?.string
                }
                let fullText = lines.joined(separator: "\n")
                
                os_log(" OCR completed: found %d lines of text", log: self.logger, type: .info, lines.count)

                DispatchQueue.main.async {
                    if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        os_log(" OCR: Extracted text is empty", log: self.logger, type: .error)
                        completion(.failure(.noTextFound))
                    } else {
                        os_log(" OCR success: %d characters extracted", log: self.logger, type: .info, fullText.count)
                        completion(.success(fullText))
                    }
                }
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-IN", "en-US"]
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.01

            let handler = VNImageRequestHandler(cgImage: cgImage,
                                                orientation: self.cgOrientation(for: image),
                                                options: [:])
            do {
                os_log(" Performing VNImageRequestHandler", log: self.logger, type: .debug)
                try handler.perform([request])
            } catch {
                os_log("VNImageRequestHandler failed: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(.ocrFailed(error.localizedDescription)))
                }
            }
        }
    }

    
    private func cgOrientation(for image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .upMirrored:
            return .upMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}
