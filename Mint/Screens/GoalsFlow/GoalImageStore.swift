import UIKit

enum GoalImageStore {

    static func url(for goalId: UUID) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("goal_\(goalId.uuidString)_photo.png")
    }

    private static func legacyURL(for goalId: UUID) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("goal_\(goalId.uuidString)_photo.jpg")
    }

    @discardableResult
    static func save(_ image: UIImage, for goalId: UUID) -> URL? {
        guard let data = image.pngData() else { return nil }
        let fileURL = url(for: goalId)

        do {
            try data.write(to: fileURL, options: .atomic)
            let oldJPEGURL = legacyURL(for: goalId)
            if FileManager.default.fileExists(atPath: oldJPEGURL.path) {
                try? FileManager.default.removeItem(at: oldJPEGURL)
            }
            return fileURL
        } catch {
            print("GoalImageStore save failed: \(error)")
            return nil
        }
    }

    static func removeImage(for goalId: UUID) {
        let urls = [url(for: goalId), legacyURL(for: goalId)]
        for fileURL in urls where FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    static func attachSavedImages(to goals: inout [Goal]) {
        for index in goals.indices {
            let pngURL = url(for: goals[index].id)
            let jpgURL = legacyURL(for: goals[index].id)

            if FileManager.default.fileExists(atPath: pngURL.path) {
                goals[index].pickedImageURL = pngURL
            } else if FileManager.default.fileExists(atPath: jpgURL.path) {
                goals[index].pickedImageURL = jpgURL
            } else {
                goals[index].pickedImageURL = nil
            }
        }
    }
}
