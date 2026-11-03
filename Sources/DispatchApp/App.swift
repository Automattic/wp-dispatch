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
        ImagePreview.clearDownloads() // anything a crash left behind
        let controller = PanelController(store: Store())
        self.controller = controller
        _ = Updates.shared // starts the daily background check
        NSApp.mainMenu = mainMenu()
        Alerts.shared.start(controller)
        controller.applyLaunchMode()
        Screenshots.stage(controller)
    }

    func applicationWillTerminate(_ notification: Notification) {
        ImagePreview.clearDownloads()
    }

    // A Dock icon click, or ⌘-Tab to Dispatch with nothing of it showing.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.reopen()
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard let controller, controller.mode == .detached, !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) else { return }
        controller.reopen()
    }

    // MARK: Menu bar
    // Only seen when Dispatch is a window (or has its Dock icon); its shortcuts work everywhere.

    private func mainMenu() -> NSMenu {
        func item(_ title: String, _ action: Selector?, _ key: String = "", _ mods: NSEvent.ModifierFlags = .command,
                  target: AnyObject? = nil) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            i.target = target
            return i
        }
        func menu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
            let m = NSMenu(title: title)
            items.forEach(m.addItem)
            let top = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            top.submenu = m
            return top
        }
        let main = NSMenu()
        main.addItem(menu("Dispatch", [
            item("About Dispatch", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item("Check for Updates…", #selector(checkForUpdates), target: self),
            .separator(),
            item("Open at Login", #selector(toggleLogin), target: self),
            item("Show in Dock", #selector(toggleDock), target: self),
            item("Open as a Window", #selector(toggleOpensAsWindow), target: self),
            .separator(),
            item("Hide Dispatch", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:))),
            .separator(),
            item("Quit Dispatch", #selector(NSApplication.terminate(_:)), "q"),
        ]))
        main.addItem(menu("Edit", [
            item("Undo", Selector(("undo:")), "z"),
            item("Redo", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
        ]))
        main.addItem(menu("View", [
            item("Refresh", #selector(refresh), "r", target: self),
            .separator(),
            item("Bigger Text", #selector(zoomIn), "+", target: self),
            item("Smaller Text", #selector(zoomOut), "-", target: self),
            item("Actual Size", #selector(zoomReset), "0", target: self),
        ]))
        main.addItem(menu("Go", [
            item("Notifications", #selector(goNotifications), "1", target: self),
            item("Reader", #selector(goReader), "2", target: self),
            item("Later", #selector(goLater), "3", target: self),
            .separator(),
            item("Keyboard Shortcuts", #selector(showKeys), "/", [.command], target: self),
        ]))
        let window = menu("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Zoom", #selector(NSWindow.performZoom(_:))),
            .separator(),
            item("Put Back in Menu Bar", #selector(putBack), target: self),
        ])
        NSApp.windowsMenu = window.submenu
        main.addItem(window)
        return main
    }

    @objc private func checkForUpdates() { Updates.shared.checkForUpdates() }
    @objc private func toggleDock() { controller?.showInDock.toggle() }
    @objc private func toggleLogin() { controller?.opensAtLogin.toggle() }
    @objc private func toggleOpensAsWindow() { controller?.opensAsWindow.toggle() }
    @objc private func putBack() { controller?.attach() }
    @objc private func goNotifications() { controller?.switchSection(.notifications) }
    @objc private func goReader() { controller?.switchSection(.reader) }
    @objc private func goLater() { controller?.switchSection(.later) }
    @objc private func showKeys() { controller?.showingKeys = true }
    @objc private func refresh() { Task { await controller?.refreshCurrent() } }
    @objc private func zoomIn() { controller?.zoom(1) }
    @objc private func zoomOut() { controller?.zoom(-1) }
    @objc private func zoomReset() { controller?.zoom(0) }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(toggleDock): item.state = controller?.showInDock == true ? .on : .off
        case #selector(toggleLogin): item.state = controller?.opensAtLogin == true ? .on : .off
        case #selector(toggleOpensAsWindow): item.state = controller?.opensAsWindow == true ? .on : .off
        case #selector(putBack): return controller?.mode == .detached
        default: break
        }
        return true
    }
}
