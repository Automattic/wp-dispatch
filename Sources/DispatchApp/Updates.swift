import AppKit
import Sparkle

/// In-app updates via Sparkle. The feed (`SUFeedURL`) and the EdDSA public key
/// (`SUPublicEDKey`) live in Info.plist; releases are made with `release.sh`.
@MainActor
final class Updates {
    static let shared = Updates()

    /// None in demo mode, which must never check for or install anything.
    private let controller = Demo.isOn ? nil : SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func checkForUpdates() { controller?.checkForUpdates(nil) }

    /// Quits and opens the app again, which picks up a freshly installed build.
    /// The helper shell outlives us and waits a moment so the new copy isn't refused as a duplicate.
    static func relaunch() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 0.6; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? p.run()
        NSApp.terminate(nil)
    }

    /// "1.2 (14)", for the menu.
    var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
