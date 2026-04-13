

import UIKit

final class ReceiptScanPipeline {

    static let shared = ReceiptScanPipeline()
    private init() {}

    func scan(image: UIImage,
              completion: @escaping (Result<ReceiptScanData, Error>) -> Void) {
        if AzureReceiptService.shared.isConfigured {
            print("[ReceiptScanPipeline] Azure is configured. Trying Azure Document Intelligence first.")
            runAzurePipeline(image: image, completion: completion)
        } else {
            let issue = AzureReceiptService.shared.configurationIssue ?? "Azure configuration unavailable"
            print("[ReceiptScanPipeline] Azure skipped: \(issue). Using local OCR pipeline.")
            runLocalPipeline(image: image, completion: completion)
        }
    }

    private func runAzurePipeline(image: UIImage,
                                  completion: @escaping (Result<ReceiptScanData, Error>) -> Void) {
        AzureReceiptService.shared.analyze(image: image) { [weak self] result in
            switch result {
            case .success(let scanData):
                print("[ReceiptScanPipeline] Azure analysis succeeded. Using Azure result in the app.")
                completion(.success(scanData))

            case .failure(let azureError):
                print("[ReceiptScanPipeline] Azure failed (\(azureError.localizedDescription)) — falling back to local pipeline.")
                self?.runLocalPipeline(image: image, completion: completion)
            }
        }
    }

    private func runLocalPipeline(image: UIImage,
                                  completion: @escaping (Result<ReceiptScanData, Error>) -> Void) {
        ReceiptOCRService.shared.recognizeText(in: image) { result in
            switch result {
            case .failure(let ocrError):
                completion(.failure(ocrError))

            case .success(let rawText):
                DispatchQueue.global(qos: .userInitiated).async {
                    let scanData = IndianReceiptParserService.shared.parse(rawText: rawText)
                    DispatchQueue.main.async {
                        completion(.success(scanData))
                    }
                }
            }
        }
    }
}
