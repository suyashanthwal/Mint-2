import CoreImage
import ImageIO
import UIKit
import Vision

enum GoalImageCutoutProcessor {

    private static let context = CIContext(options: nil)

    static func process(_ image: UIImage) async -> UIImage {
        guard #available(iOS 18.0, *),
              let cgImage = image.cgImage else {
            return image
        }

        do {
            let orientation = cgOrientation(for: image)
            let handler = ImageRequestHandler(cgImage, orientation: orientation)
            let request = GenerateForegroundInstanceMaskRequest(.revision1)

            guard let observation = try await handler.perform(request),
                  !observation.allInstances.isEmpty else {
                return image
            }

            let maskedBuffer = try observation.generateMaskedImage(
                for: observation.allInstances,
                imageFrom: handler,
                croppedToInstancesExtent: true
            )

            let ciImage = CIImage(cvPixelBuffer: maskedBuffer)
            guard let outputImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                return image
            }

            return UIImage(cgImage: outputImage, scale: image.scale, orientation: .up)
        } catch {
            print("GoalImageCutoutProcessor failed: \(error)")
            return image
        }
    }

    private static func cgOrientation(for image: UIImage) -> CGImagePropertyOrientation {
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
