//
//  Receiptscanpipeline.swift
//  QrAndReceiptReading
//
//  Created by Ayush Singh Bhandari on 07/04/26.

//  Single entry point for receipt scanning.
//  Tries Azure Document Intelligence first when it is configured, then
//  falls back to the local Vision + regex pipeline if the remote path fails.
//
//  We intentionally avoid preflight reachability checks here. Apple's modern
//  networking guidance favors attempting the request and handling failure over
//  trying to predict connectivity up front.
//
//  Usage (in your ViewController):
//
//      ReceiptScanPipeline.shared.scan(image: image) { result in
//          // always called on main thread
//          switch result {
//          case .success(let scanData):
//              self.navigateToReceiptReview(scanData: scanData, image: image)
//          case .failure(let error):
//              self.showError(error.localizedDescription)
//          }
//      }
//

import UIKit

final class ReceiptScanPipeline {

    static let shared = ReceiptScanPipeline()
    private init() {}

    // MARK: - Public API

    /// Scans a receipt image and returns populated `ReceiptScanData`.
    /// Always calls `completion` on the **main thread**.
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

    //  Azure Pipeline

    private func runAzurePipeline(image: UIImage,
                                  completion: @escaping (Result<ReceiptScanData, Error>) -> Void) {
        AzureReceiptService.shared.analyze(image: image) { [weak self] result in
            // AzureReceiptService already delivers on main thread
            switch result {
            case .success(let scanData):
                print("[ReceiptScanPipeline] Azure analysis succeeded. Using Azure result in the app.")
                completion(.success(scanData))

            case .failure(let azureError):
                // Azure failed — log it and fall back to local OCR
                print("[ReceiptScanPipeline] Azure failed (\(azureError.localizedDescription)) — falling back to local pipeline.")
                self?.runLocalPipeline(image: image, completion: completion)
            }
        }
    }

    // Local Fallback Pipeline (Vision + regex)

    private func runLocalPipeline(image: UIImage,
                                  completion: @escaping (Result<ReceiptScanData, Error>) -> Void) {
        ReceiptOCRService.shared.recognizeText(in: image) { result in
            // ReceiptOCRService already delivers on main thread
            switch result {
            case .failure(let ocrError):
                completion(.failure(ocrError))

            case .success(let rawText):
                // Parser is synchronous — push off main thread so UI stays responsive
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
