import Foundation

/// Saved login, stored as a user-only (0600) JSON file in Application Support.
/// Not the Keychain: ad-hoc signed rebuilds change the app's identity, which makes
/// the Keychain re-prompt for a password on every launch.
enum Credentials {
    private static let file: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WPNotifications", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        return dir.appendingPathComponent("credentials.json")
    }()

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
