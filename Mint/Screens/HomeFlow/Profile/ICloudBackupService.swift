import Foundation

final class ICloudBackupService {
    static let shared = ICloudBackupService()

    private struct BackupMetadata: Codable {
        let appleAccountLinks: [String: String]
        let setupCompletedUserIds: [String]
        let isBackupEnabled: Bool
    }

    private enum Keys {
        static let appleLinks = "apple_account_links"
        static let setupCompleted = "setup_completed_user_ids"
        static let backupEnabled = "isBackupEnabled"
    }

    private init() {}

    var isBackupEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.backupEnabled)
    }

    func setBackupEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Keys.backupEnabled)
    }

    func canUseBackupForCurrentUser() -> Bool {
        DatabaseManager.shared.currentAuthenticationProvider == .apple
            && DatabaseManager.shared.currentAppleUserIdentifier != nil
    }

    func syncCurrentUserBackup() throws {
        guard DatabaseManager.shared.currentAuthenticationProvider == .apple,
              let appleUserIdentifier = DatabaseManager.shared.currentAppleUserIdentifier
        else {
            throw BackupError.appleSignInRequired
        }

        let backupDirectory = try backupDirectoryURL(forAppleUserIdentifier: appleUserIdentifier)
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try removeExistingBackupContents(at: backupDirectory)

        DatabaseManager.shared.checkpointForBackup()

        for localURL in DatabaseManager.shared.databaseSupportFileURLs() where fileManager.fileExists(atPath: localURL.path) {
            let destinationURL = backupDirectory.appendingPathComponent(localURL.lastPathComponent)
            try fileManager.copyItem(at: localURL, to: destinationURL)
        }

        let profileImagesURL = ProfileImageStore.imagesFolderURL()
        if fileManager.fileExists(atPath: profileImagesURL.path) {
            let destinationURL = backupDirectory.appendingPathComponent(profileImagesURL.lastPathComponent, isDirectory: true)
            try fileManager.copyItem(at: profileImagesURL, to: destinationURL)
        }

        let metadataURL = backupDirectory.appendingPathComponent("metadata.json")
        let metadata = BackupMetadata(
            appleAccountLinks: UserDefaults.standard.dictionary(forKey: Keys.appleLinks) as? [String: String] ?? [:],
            setupCompletedUserIds: UserDefaults.standard.stringArray(forKey: Keys.setupCompleted) ?? [],
            isBackupEnabled: true
        )
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL, options: .atomic)
    }

    func removeBackupForCurrentUser() throws {
        guard let appleUserIdentifier = DatabaseManager.shared.currentAppleUserIdentifier else { return }
        let backupDirectory = try backupDirectoryURL(forAppleUserIdentifier: appleUserIdentifier)
        guard FileManager.default.fileExists(atPath: backupDirectory.path) else { return }
        try FileManager.default.removeItem(at: backupDirectory)
    }

    @discardableResult
    func restoreBackupIfAvailable(forAppleUserIdentifier appleUserIdentifier: String) throws -> Bool {
        guard DatabaseManager.shared.countNonAdminUsers() == 0 else { return false }

        let backupDirectory = try backupDirectoryURL(forAppleUserIdentifier: appleUserIdentifier)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: backupDirectory.path) else { return false }

        let databaseURLs = DatabaseManager.shared.databaseSupportFileURLs()
            .map { backupDirectory.appendingPathComponent($0.lastPathComponent) }
            .filter { fileManager.fileExists(atPath: $0.path) }

        guard databaseURLs.contains(where: { $0.lastPathComponent == "mint.sqlite" }) else { return false }
        guard DatabaseManager.shared.replaceDatabaseFiles(with: databaseURLs) else { return false }

        try restoreProfileImages(from: backupDirectory)
        try restoreMetadata(from: backupDirectory)
        return true
    }

    private func restoreProfileImages(from backupDirectory: URL) throws {
        let fileManager = FileManager.default
        let localImagesURL = ProfileImageStore.imagesFolderURL()
        let remoteImagesURL = backupDirectory.appendingPathComponent(localImagesURL.lastPathComponent, isDirectory: true)

        if fileManager.fileExists(atPath: localImagesURL.path) {
            try fileManager.removeItem(at: localImagesURL)
        }

        if fileManager.fileExists(atPath: remoteImagesURL.path) {
            try fileManager.copyItem(at: remoteImagesURL, to: localImagesURL)
        }
    }

    private func restoreMetadata(from backupDirectory: URL) throws {
        let metadataURL = backupDirectory.appendingPathComponent("metadata.json")
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return }

        let data = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(BackupMetadata.self, from: data)

        UserDefaults.standard.set(metadata.appleAccountLinks, forKey: Keys.appleLinks)
        UserDefaults.standard.set(metadata.setupCompletedUserIds, forKey: Keys.setupCompleted)
        UserDefaults.standard.set(metadata.isBackupEnabled, forKey: Keys.backupEnabled)
    }

    private func backupDirectoryURL(forAppleUserIdentifier appleUserIdentifier: String) throws -> URL {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier) else {
            throw BackupError.iCloudUnavailable
        }

        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let sanitizedIdentifier = appleUserIdentifier.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        return documentsURL
            .appendingPathComponent("MintBackups", isDirectory: true)
            .appendingPathComponent(sanitizedIdentifier, isDirectory: true)
    }

    private func removeExistingBackupContents(at directory: URL) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory.path) { return }

        try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).forEach {
            try fileManager.removeItem(at: $0)
        }
    }

    private var iCloudContainerIdentifier: String {
        "iCloud.com.Suyash.Mint"
    }
}

extension ICloudBackupService {
    enum BackupError: LocalizedError {
        case appleSignInRequired
        case iCloudUnavailable

        var errorDescription: String? {
            switch self {
            case .appleSignInRequired:
                return "Sign in with Apple to use iCloud backup."
            case .iCloudUnavailable:
                return "iCloud Drive is unavailable on this device right now."
            }
        }
    }
}
