import AppKit

// Plain AppKit entry point: the UI lives in PanelController's own panel/window.
// (A SwiftUI `App` needs a scene, and its Settings scene pops an empty window.)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = PanelController(store: Store())
    }
}
