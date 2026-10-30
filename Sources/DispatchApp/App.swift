import AppKit

// Plain AppKit entry point: the UI lives in PanelController's own panel/window.
// (A SwiftUI `App` needs a scene, and its Settings scene pops an empty window.)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: PanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Demo.isRendering {
            let controller = PanelController(store: Store())
            self.controller = controller
            Task {
                await DemoRender.run(controller)
                NSApp.terminate(nil)
            }
            return
        }
        AppData.migrateFromOldName()
        controller = PanelController(store: Store())
        _ = Updates.shared // starts the daily background check
        if let controller { Screenshots.stage(controller) }
    }
}
