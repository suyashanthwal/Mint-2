import UIKit

enum ProfileImageStore {
    private static let directoryName = "ProfileImages"

    private static var imagesDirectoryURL: URL {
        let baseURL = DatabaseManager.shared.documentsDirectoryURL()
        return baseURL.appendingPathComponent(directoryName, isDirectory: true)
    }

    @discardableResult
    static func save(image: UIImage) -> String? {
        let fileManager = FileManager.default
        let fileName = "profile-\(UUID().uuidString).jpg"
        let fileURL = imagesDirectoryURL.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }

        do {
            try fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            print("ProfileImageStore.save failed: \(error)")
            return nil
        }
    }

    static func loadImage(named fileName: String?) -> UIImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        let fileURL = imagesDirectoryURL.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: fileURL.path)
    }

    static func deleteImage(named fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        let fileURL = imagesDirectoryURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("ProfileImageStore.deleteImage failed: \(error)")
        }
    }

    static func imagesFolderURL() -> URL {
        imagesDirectoryURL
    }
}
