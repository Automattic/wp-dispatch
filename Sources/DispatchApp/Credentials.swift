import Foundation

/// `~/Library/Application Support/Dispatch`, user-only (0700).
enum AppData {
    static let directory: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dispatch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        return dir
    }()

    /// The app was "WP Notifications" (com.shaunandrews.wpnotifications) before it was Dispatch.
    /// Carries over the sign-in, stars/saves and panel settings once. Run before anything reads them.
    static func migrateFromOldName() {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let old = support.appendingPathComponent("WPNotifications", isDirectory: true)
        let new = support.appendingPathComponent("Dispatch", isDirectory: true)
        if fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) {
            try? fm.moveItem(at: old, to: new)
        }
        let defaults = UserDefaults.standard
        if let oldDefaults = UserDefaults(suiteName: "com.shaunandrews.wpnotifications") {
            for key in ["section", "unreadOnly", "panelHeight", "windowFrame"]
            where defaults.object(forKey: key) == nil {
                if let value = oldDefaults.object(forKey: key) { defaults.set(value, forKey: key) }
            }
        }
    }
}

/// Saved login, stored as a user-only (0600) JSON file in Application Support.
/// Not the Keychain: ad-hoc signed rebuilds change the app's identity, which makes
/// the Keychain re-prompt for a password on every launch.
enum Credentials {
    private static let file = AppData.directory.appendingPathComponent("credentials.json")

    private static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: file) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    static func get(_ key: String) -> String? { load()[key] }

    static func set(_ key: String, _ value: String?) {
        var all = load()
        all[key] = (value?.isEmpty ?? true) ? nil : value
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? data.write(to: file, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
