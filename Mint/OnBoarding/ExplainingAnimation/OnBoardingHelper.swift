import Foundation

struct OnboardingHelper {

    static func shouldShow(key: String) -> Bool {
        guard let userId = DatabaseManager.shared.currentUserId else {
            return !UserDefaults.standard.bool(forKey: key)
        }

        if DatabaseManager.shared.hasSeenOnboarding(key: key, for: userId) {
            return false
        }

        // Migrate any previously stored local state into the DB-backed table.
        if UserDefaults.standard.bool(forKey: legacyScopedKey(for: key, userId: userId)) {
            DatabaseManager.shared.markOnboardingSeen(key: key, for: userId)
            return false
        }

        return true
    }

    static func markSeen(key: String) {
        if let userId = DatabaseManager.shared.currentUserId {
            DatabaseManager.shared.markOnboardingSeen(key: key, for: userId)
            UserDefaults.standard.set(true, forKey: legacyScopedKey(for: key, userId: userId))
        } else {
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    private static func legacyScopedKey(for key: String, userId: UUID) -> String {
        "\(key)_\(userId.uuidString)"
    }
}
