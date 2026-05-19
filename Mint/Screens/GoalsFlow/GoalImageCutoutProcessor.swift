import CoreImage
import ImageIO
import UIKit
import Vision

enum GoalImageCutoutProcessor {

    private static let context = CIContext(options: nil)
    private static let whiteBackgroundTolerance = 26
    private static let edgeSamplingInset = 4
    private static let minimumBackgroundMatches = 3

    static func process(_ image: UIImage) async -> UIImage {
        guard let cgImage = image.cgImage else {
            return image
        }

        if #available(iOS 18.0, *) {
            do {
                let orientation = cgOrientation(for: image)
                let handler = ImageRequestHandler(cgImage, orientation: orientation)
                let request = GenerateForegroundInstanceMaskRequest(.revision1)

                guard let observation = try await handler.perform(request),
                      !observation.allInstances.isEmpty else {
                    return removeLikelySolidBackground(from: image)
                }

                let maskedBuffer = try observation.generateMaskedImage(
                    for: observation.allInstances,
                    imageFrom: handler,
                    croppedToInstancesExtent: true
                )

                let ciImage = CIImage(cvPixelBuffer: maskedBuffer)
                guard let outputImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                    return removeLikelySolidBackground(from: image)
                }

                let isolatedImage = UIImage(cgImage: outputImage, scale: image.scale, orientation: .up)
                return removeLikelySolidBackground(from: isolatedImage)
            } catch {
                print("GoalImageCutoutProcessor failed: \(error)")
            }
        }

        return removeLikelySolidBackground(from: image)
    }

    static func hasLikelyRemovableBackground(_ image: UIImage) -> Bool {
        guard let analysis = analyzeEdgeBackground(in: image) else { return false }
        return analysis.matchCount >= minimumBackgroundMatches
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

    private static func removeLikelySolidBackground(from image: UIImage) -> UIImage {
        guard let analysis = analyzeEdgeBackground(in: image),
              analysis.matchCount >= minimumBackgroundMatches,
              let cleanedImage = floodFillTransparentBackground(in: analysis) else {
            return image
        }

        return cleanedImage
    }

    private static func analyzeEdgeBackground(in image: UIImage) -> BackgroundAnalysis? {
        guard let cgImage = image.cgImage,
              let rgba = RGBAImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation) else {
            return nil
        }

        let width = rgba.width
        let height = rgba.height
        guard width > 2, height > 2 else { return nil }

        let insetX = min(edgeSamplingInset, max(0, width / 8))
        let insetY = min(edgeSamplingInset, max(0, height / 8))

        let samplePoints = [
            (x: insetX, y: insetY),
            (x: max(0, width - 1 - insetX), y: insetY),
            (x: insetX, y: max(0, height - 1 - insetY)),
            (x: max(0, width - 1 - insetX), y: max(0, height - 1 - insetY))
        ]

        let opaqueSamples = samplePoints.compactMap { point -> RGBColor? in
            let pixel = rgba.pixelAt(x: point.x, y: point.y)
            guard pixel.a > 230 else { return nil }
            return RGBColor(r: pixel.r, g: pixel.g, b: pixel.b)
        }

        guard let candidate = dominantSample(in: opaqueSamples) else { return nil }

        let whiteishMatchCount = opaqueSamples.reduce(into: 0) { count, sample in
            if sample.isNearWhite && sample.distance(to: candidate) <= whiteBackgroundTolerance {
                count += 1
            }
        }

        guard whiteishMatchCount >= minimumBackgroundMatches else { return nil }

        return BackgroundAnalysis(rgba: rgba, backgroundColor: candidate, matchCount: whiteishMatchCount)
    }

    private static func dominantSample(in samples: [RGBColor]) -> RGBColor? {
        guard !samples.isEmpty else { return nil }

        var bestSample = samples[0]
        var bestScore = -1

        for sample in samples {
            let score = samples.reduce(into: 0) { total, candidate in
                if sample.distance(to: candidate) <= whiteBackgroundTolerance {
                    total += 1
                }
            }

            if score > bestScore {
                bestScore = score
                bestSample = sample
            }
        }

        return bestSample
    }

    private static func floodFillTransparentBackground(in analysis: BackgroundAnalysis) -> UIImage? {
        var rgba = analysis.rgba
        let width = rgba.width
        let height = rgba.height
        var queue: [(x: Int, y: Int)] = []
        var visited = Array(repeating: false, count: width * height)

        func enqueue(_ x: Int, _ y: Int) {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            let index = y * width + x
            guard !visited[index] else { return }

            let pixel = rgba.pixelAt(x: x, y: y)
            guard pixelMatchesBackground(pixel, background: analysis.backgroundColor) else { return }

            visited[index] = true
            queue.append((x: x, y: y))
        }

        for x in 0..<width {
            enqueue(x, 0)
            enqueue(x, height - 1)
        }

        for y in 0..<height {
            enqueue(0, y)
            enqueue(width - 1, y)
        }

        var index = 0
        while index < queue.count {
            let point = queue[index]
            index += 1

            rgba.setAlpha(0, atX: point.x, y: point.y)

            enqueue(point.x + 1, point.y)
            enqueue(point.x - 1, point.y)
            enqueue(point.x, point.y + 1)
            enqueue(point.x, point.y - 1)
        }

        return rgba.makeImage(scale: analysis.rgba.scale, orientation: analysis.rgba.orientation)
    }

    private static func pixelMatchesBackground(_ pixel: RGBAPixel, background: RGBColor) -> Bool {
        guard pixel.a > 230 else { return false }

        let color = RGBColor(r: pixel.r, g: pixel.g, b: pixel.b)
        return color.isNearWhite && color.distance(to: background) <= whiteBackgroundTolerance
    }
}

private struct BackgroundAnalysis {
    let rgba: RGBAImage
    let backgroundColor: RGBColor
    let matchCount: Int
}

private struct RGBColor {
    let r: UInt8
    let g: UInt8
    let b: UInt8

    var isNearWhite: Bool {
        Int(r) >= 225 && Int(g) >= 225 && Int(b) >= 225
    }

    func distance(to other: RGBColor) -> Int {
        max(abs(Int(r) - Int(other.r)),
            abs(Int(g) - Int(other.g)),
            abs(Int(b) - Int(other.b)))
    }
}

private struct RGBAPixel {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8
}

private struct RGBAImage {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let scale: CGFloat
    let orientation: UIImage.Orientation
    private var pixels: [UInt8]

    init?(cgImage: CGImage, scale: CGFloat = 1, orientation: UIImage.Orientation = .up) {
        self.width = cgImage.width
        self.height = cgImage.height
        self.bytesPerRow = width * 4
        self.scale = scale
        self.orientation = orientation
        self.pixels = Array(repeating: 0, count: height * bytesPerRow)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func pixelAt(x: Int, y: Int) -> RGBAPixel {
        let offset = y * bytesPerRow + x * 4
        return RGBAPixel(
            r: pixels[offset],
            g: pixels[offset + 1],
            b: pixels[offset + 2],
            a: pixels[offset + 3]
        )
    }

    mutating func setAlpha(_ alpha: UInt8, atX x: Int, y: Int) {
        let offset = y * bytesPerRow + x * 4
        pixels[offset + 3] = alpha
    }

    func makeImage(scale: CGFloat, orientation: UIImage.Orientation) -> UIImage? {
        var bytes = pixels
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    }
}
