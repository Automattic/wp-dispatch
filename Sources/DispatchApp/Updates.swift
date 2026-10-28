import Foundation
import Sparkle

/// In-app updates via Sparkle. The feed (`SUFeedURL`) and the EdDSA public key
/// (`SUPublicEDKey`) live in Info.plist; releases are made with `release.sh`.
@MainActor
final class Updates {
    static let shared = Updates()

    private let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func checkForUpdates() { controller.checkForUpdates(nil) }

    /// "1.2 (14)", for the menu.
    var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
