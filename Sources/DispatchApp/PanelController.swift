import AppKit
import Combine
import SwiftUI
import WebKit

/// Borderless panels can't become key by default; we need key for keyboard nav and text fields.
final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Owns the status item and the two homes for the UI: a panel hanging off the
/// menu bar (attached) and a regular resizable window (detached). The same
/// SwiftUI view moves between them, so state survives the switch.
@MainActor
final class PanelController: NSObject, ObservableObject, NSWindowDelegate {
    enum Mode { case attached, detached }
    enum Section: String { case notifications, reader }

    @Published private(set) var mode: Mode = .attached
    @Published private(set) var showDetail = false
    @Published private(set) var selectedID: Int?
    @Published private(set) var selectedPostID: String?
    @Published private(set) var section = Section(rawValue: UserDefaults.standard.string(forKey: "section") ?? "") ?? .notifications
    /// Notes read during this session stay in the Unread list until the panel closes.
    @Published private(set) var keptVisible: Set<Int> = []
    /// Comments drawer under the reader; starts closed each launch, then sticks while you move between posts.
    @Published var commentsOpen = false
    /// The open drawer takes the reader's whole height, over the article. Sticks between posts too.
    @Published var commentsExpanded = false
    /// Set by the list as it scrolls; shows the back-to-top button.
    @Published var listScrolled = false
    /// Bumped to ask the visible list to scroll to its top.
    @Published private(set) var scrollToTopRequest = 0
    @Published var unreadOnly = UserDefaults.standard.bool(forKey: "unreadOnly") {
        didSet { UserDefaults.standard.set(unreadOnly, forKey: "unreadOnly") }
    }
    /// A Dock icon even while Dispatch lives in the menu bar. As a window it always has one.
    @Published var showInDock = UserDefaults.standard.bool(forKey: "showInDock") {
        didSet { UserDefaults.standard.set(showInDock, forKey: "showInDock"); updateDockIcon() }
    }
    /// Launch as a window instead of in the menu bar.
    @Published var opensAsWindow = UserDefaults.standard.bool(forKey: "opensAsWindow") {
        didSet { UserDefaults.standard.set(opensAsWindow, forKey: "opensAsWindow") }
    }

    let store: Store
    let reader: ReaderStore
    let listWidth: CGFloat = 380
    let detailWidth: CGFloat = 540
    private let minDetailWidth: CGFloat = 420

    /// None while rendering the website's demo scenes, which stay out of the menu bar.
    private let statusItem = Demo.isRendering ? nil : NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: Panel
    private let panelBackground = PanelController.background(rounded: true)
    private var window: NSWindow?
    private var windowBackground: NSVisualEffectView?
    private var hosting: NSHostingView<AnyView>!
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var resizeStart: (height: CGFloat, mouseY: CGFloat)?
    private var showGeneration = 0
    private var bag = Set<AnyCancellable>()

    var visibleNotes: [Note] {
        store.notes.filter { !unreadOnly || $0.isUnread || keptVisible.contains($0.id) }
    }
    var selectedNote: Note? { store.notes.first { $0.id == selectedID } }
    /// Kept so the open post stays put when the list switches feeds underneath it.
    private var currentPost: ReaderPost?
    var selectedPost: ReaderPost? {
        guard let id = selectedPostID else { return nil }
        return reader.posts.first { $0.id == id } ?? currentPost
    }
    /// Where the open item's comments live. X-posts point at the original; RSS-only blogs have none.
    var commentTarget: (site: Int, post: Int)? {
        switch section {
        case .notifications:
            guard let ids = selectedNote?.meta?.ids, let site = ids.site, let post = ids.post else { return nil }
            return (site, post)
        case .reader:
            guard let p = selectedPost else { return nil }
            if let origin = p.xpostOrigin { return origin }
            return p.isExternal ? nil : (p.site_ID, p.postID)
        }
    }
    private var hasSelection: Bool { selectedID != nil || selectedPostID != nil }

    private var panelHeight: CGFloat {
        get { let h = UserDefaults.standard.double(forKey: "panelHeight"); return h > 0 ? h : 620 }
        set { UserDefaults.standard.set(newValue, forKey: "panelHeight") }
    }
    private var savedWindowFrame: NSRect? {
        get { UserDefaults.standard.string(forKey: "windowFrame").map(NSRectFromString) }
        set { UserDefaults.standard.set(newValue.map(NSStringFromRect), forKey: "windowFrame") }
    }

    init(store: Store) {
        self.store = store
        reader = ReaderStore(store: store)
        panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 620),
                      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()

        hosting = NSHostingView(rootView: AnyView(RootView().environmentObject(store).environmentObject(reader).environmentObject(self)))
        hosting.sizingOptions = []

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentView = panelBackground
        embed(hosting, in: panelBackground)

        if let button = statusItem?.button {
            button.image = WordPressLogo.image
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(toggle)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        store.$notes.sink { [weak self] notes in
            self?.setBadge(notes.filter(\.isUnread).count)
        }.store(in: &bag)

        // Connecting swaps the setup form for the list; resize to fit. Sign-in finishes in the
        // browser (which hides the panel), so bring the panel back once it lands.
        store.$token.dropFirst().receive(on: RunLoop.main).sink { [weak self] token in
            guard let self, self.mode == .attached else { return }
            if self.panel.isVisible {
                self.animate(self.panel, to: self.attachedFrame(), duration: 0.3)
            } else if token != nil {
                self.showPanel()
            }
        }.store(in: &bag)

        if section == .reader { Task { await reader.refresh() } }

        NotificationCenter.default.publisher(for: .openSite).sink { [weak self] note in
            (note.object as? URL).map { self?.openSite($0) }
        }.store(in: &bag)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Not `self?.handleKey(event) ?? event`: a handled key returns nil, and `??`
            // would turn that back into the event, which then beeps as unhandled.
            MainActor.assumeIsolated {
                guard let self else { return event }
                return self.handleKey(event)
            }
        }
    }

    // MARK: Dock

    /// A window should act like any other app's: in the Dock, in ⌘-Tab, with a menu bar.
    /// In the menu bar Dispatch is an accessory app, unless the Dock icon is turned on.
    func updateDockIcon() {
        guard !Demo.isOn else { return }
        let policy: NSApplication.ActivationPolicy = showInDock || mode == .detached ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if policy == .regular, mode == .detached { NSApp.activate(ignoringOtherApps: true) }
    }

    /// The Dock icon was clicked, or Dispatch was picked in ⌘-Tab, with nothing of it on screen.
    func reopen() {
        switch mode {
        case .detached:
            NSApp.activate(ignoringOtherApps: true)
            if window?.isMiniaturized == true { window?.deminiaturize(nil) }
            window?.makeKeyAndOrderFront(nil)
        case .attached:
            if !panel.isVisible || panel.alphaValue == 0 { showPanel() }
        }
    }

    /// At launch: open as a window if that's the setting.
    func applyLaunchMode() {
        if opensAsWindow && store.isConnected { detach() } else { updateDockIcon() }
    }

    // MARK: Status item

    private func setBadge(_ count: Int) {
        guard let button = statusItem?.button else { return }
        button.attributedTitle = NSAttributedString(
            string: count > 0 ? "\(count)" : "",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)])
    }

    @objc private func toggle() {
        switch mode {
        case .detached:
            guard let window else { return }
            if window.isVisible && window.isKeyWindow {
                window.orderOut(nil)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        case .attached:
            panel.isVisible && panel.alphaValue > 0 ? hidePanel() : showPanel()
        }
    }

    // MARK: Attached panel

    /// The list sits centered under the menu bar icon; the reader grows out to its left.
    private func attachedFrame(width: CGFloat? = nil) -> NSRect {
        guard let button = statusItem?.button, let bw = button.window,
              let screen = bw.screen ?? NSScreen.main else { return panel.frame }
        let icon = bw.convertToScreen(button.convert(button.bounds, to: nil))
        let vis = screen.visibleFrame
        let connected = store.isConnected
        let w = width ?? (listWidth + (showDetail && connected ? detailWidth + 1 : 0))
        let h = connected ? min(max(panelHeight, 320), vis.height - 16) : 150

        let listX = min(icon.midX - listWidth / 2, vis.maxX - 8 - listWidth)
        let x = max(listX + listWidth - w, vis.minX + 8)
        return NSRect(x: x, y: vis.maxY - 6 - h, width: w, height: h)
    }

    func showPanel() {
        showGeneration += 1
        keptVisible = []
        let target = attachedFrame()
        panel.setFrame(target.offsetBy(dx: 0, dy: 8), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        animate(panel, to: target, alpha: 1, duration: 0.22)
        statusItem?.button?.highlight(true)

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.hidePanel() }
        }
        Task {
            await store.refresh()
            if section == .reader { await reader.refresh() }
        }
    }

    func hidePanel() {
        Hovercard.shared.hide()
        guard panel.isVisible else { return }
        removeClickMonitor()
        statusItem?.button?.highlight(false)
        let generation = showGeneration
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.showGeneration == generation else { return }
                self.panel.orderOut(nil)
                self.showDetail = false
                self.clearSelection()
                self.keptVisible = []
            }
        })
    }

    private func removeClickMonitor() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }

    // MARK: Selection

    func switchSection(_ new: Section) {
        guard new != section else { return }
        UserDefaults.standard.set(new.rawValue, forKey: "section")
        if mode == .attached && showDetail { closeDetail() } else { clearSelection() }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { section = new }
        if new == .reader { Task { await reader.refresh() } }
    }

    /// Demo rendering: back to a fresh launch, with nothing open.
    func resetForDemo() {
        mode = .attached
        showDetail = false
        selectedID = nil
        selectedPostID = nil
        currentPost = nil
        keptVisible = []
        commentsOpen = false
        commentsExpanded = false
        unreadOnly = false
        section = .notifications
        reader.show(.blogs)
    }

    func select(_ note: Note) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { selectedID = note.id }
        keptVisible.insert(note.id)
        store.markRead(note)
        if let i = visibleNotes.firstIndex(where: { $0.id == note.id }), i + 1 < visibleNotes.count {
            store.prefetch(visibleNotes[i + 1])
        }
        openDetail()
    }

    func select(_ post: ReaderPost) {
        currentPost = post
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { selectedPostID = post.id }
        let posts = reader.posts
        if let i = posts.firstIndex(of: post), i + 1 < posts.count { reader.prefetch(posts[i + 1]) }
        openDetail()
    }

    private func openDetail() {
        if mode == .attached && !showDetail {
            showDetail = true
            animate(panel, to: attachedFrame(), duration: 0.34)
        }
    }

    private func clearSelection() {
        selectedID = nil
        selectedPostID = nil
        currentPost = nil
    }

    func closeDetail() {
        guard mode == .attached, showDetail else {
            withAnimation(.easeOut(duration: 0.2)) { clearSelection() }
            return
        }
        animate(panel, to: attachedFrame(width: listWidth), duration: 0.26) { [weak self] in
            self?.showDetail = false
            self?.clearSelection()
        }
    }

    /// A site name clicked in the reader: show that site's feed in the list.
    /// From a Reader post the post stays open; from a notification we switch to the Reader.
    func openSite(_ url: URL) {
        guard let id = Int(url.lastPathComponent) else { return }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        openSite(id, isFeed: query.first { $0.name == "feed" }?.value == "1",
                 name: query.first { $0.name == "name" }?.value)
    }

    func openSite(_ id: Int, isFeed: Bool = false, name: String?) {
        // Name (and icon, when it's the open post's site) so the header isn't blank while it loads.
        let icon = currentPost.flatMap { $0.site_ID == id ? reader.icon(for: $0) : nil } ?? reader.icon(forSite: id)
        if let name { reader.remember(ReaderSite(id: id, name: name, icon: icon, isFeed: isFeed)) }
        if section != .reader { switchSection(.reader) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { reader.show(.site(id, isFeed: isFeed)) }
    }

    func move(_ delta: Int) {
        func step<T>(_ list: [T], _ current: Int?) -> T? {
            guard !list.isEmpty else { return nil }
            return list[current.map { min(max($0 + delta, 0), list.count - 1) } ?? 0]
        }
        switch section {
        case .notifications:
            let list = visibleNotes
            if let note = step(list, list.firstIndex { $0.id == selectedID }) { select(note) }
        case .reader:
            let list = reader.posts
            if let post = step(list, list.firstIndex { $0.id == selectedPostID }) { select(post) }
            if let i = list.firstIndex(where: { $0.id == selectedPostID }), i >= list.count - 3 {
                Task { await reader.loadMore() }
            }
        }
    }

    var position: (index: Int, count: Int)? {
        switch section {
        case .notifications:
            let list = visibleNotes
            return list.firstIndex { $0.id == selectedID }.map { ($0, list.count) }
        case .reader:
            let list = reader.posts
            return list.firstIndex { $0.id == selectedPostID }.map { ($0, list.count) }
        }
    }

    func scrollToTop() { scrollToTopRequest += 1 }

    /// ←/→ in the Reader: the next feed tab over. Not in a single site's feed (it has no tabs).
    private func switchFeed(_ delta: Int) -> Bool {
        let tabs: [ReaderStore.Feed] = [.blogs, .p2s, .saved]
        guard section == .reader, let i = tabs.firstIndex(of: reader.feed) else { return false }
        let next = tabs[min(max(i + delta, 0), tabs.count - 1)]
        if next != reader.feed { reader.show(next) }
        return true
    }

    func openSelectedInBrowser() {
        let link = section == .notifications ? selectedNote?.url : (selectedPost?.originalURL ?? selectedPost?.URL)
        guard let link, let url = URL(string: link) else { return }
        NSWorkspace.shared.open(url)
        if mode == .attached { hidePanel() }
    }

    func refreshCurrent() async {
        switch section {
        case .notifications: await store.refresh()
        case .reader: await reader.refresh()
        }
    }

    // MARK: Height handle

    func beginResize() { resizeStart = (panel.frame.height, NSEvent.mouseLocation.y) }

    func updateResize() {
        guard let start = resizeStart, let vis = panel.screen?.visibleFrame else { return }
        let h = min(max(start.height + (start.mouseY - NSEvent.mouseLocation.y), 320), vis.height - 16)
        var f = panel.frame
        f.origin.y = f.maxY - h
        f.size.height = h
        panel.setFrame(f, display: true)
        panelHeight = h
    }

    func endResize() { resizeStart = nil }

    // MARK: Tear-off window

    /// Header drag. Attached: we move the panel ourselves and detach on drop.
    /// Detached: hand it to the system so snapping/tiling work.
    func dragWindow(with event: NSEvent) {
        if mode == .detached {
            window?.performDrag(with: event)
            return
        }
        let start = NSEvent.mouseLocation
        let origin = panel.frame.origin
        var moved = false
        while let e = panel.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let p = NSEvent.mouseLocation
            let dx = p.x - start.x, dy = p.y - start.y
            if !moved && hypot(dx, dy) > 4 { moved = true }
            if moved { panel.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy)) }
            if e.type == .leftMouseUp { break }
        }
        if moved { detach(dropped: panel.frame) }
    }

    /// `dropped` is where the panel was let go; otherwise reuse the last window frame.
    func detach(dropped: NSRect? = nil) {
        let window = self.window ?? makeWindow()
        // From the panel when it's open; otherwise (at launch) straight to the window's spot.
        var target = dropped ?? savedWindowFrame ?? centeredWindowFrame()
        let start = dropped ?? (panel.isVisible ? panel.frame : target)
        let wanted = listWidth + 1 + detailWidth
        if target.width < wanted {
            target.origin.x -= wanted - target.width
            target.size.width = wanted
        }
        if let vis = (panel.screen ?? NSScreen.main)?.visibleFrame, target.minX < vis.minX + 8 {
            target.origin.x = vis.minX + 8
        }

        removeClickMonitor()
        statusItem?.button?.highlight(false)
        mode = .detached
        showDetail = true
        move(hosting, to: windowBackground!)
        updateDockIcon()

        window.setFrame(start, display: true)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        panel.orderOut(nil)
        if target != start { animate(window, to: target, duration: 0.32) }
    }

    /// Back to the menu bar. `show` re-opens the panel right away.
    func attach(show: Bool = true) {
        guard let window else { return }
        savedWindowFrame = window.frame
        window.orderOut(nil)
        mode = .attached
        updateDockIcon()
        move(hosting, to: panelBackground)
        showDetail = show && hasSelection
        if !show { clearSelection() }
        if show { showPanel() }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        attach(show: false)
        return false
    }

    /// A first window, before there's a saved spot: list and reader at full size, centered.
    private func centeredWindowFrame() -> NSRect {
        let vis = (NSScreen.main ?? panel.screen)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let size = NSSize(width: listWidth + 1 + detailWidth, height: min(panelHeight, vis.height - 80))
        return NSRect(x: vis.midX - size.width / 2, y: vis.midY - size.height / 2, width: size.width, height: size.height)
    }

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: .zero,
                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.title = "Dispatch" // for the Window menu and Mission Control; the title bar stays hidden
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        for b in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            w.standardWindowButton(b)?.isHidden = true
        }
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: listWidth + 1 + minDetailWidth, height: 360)
        w.delegate = self
        let bg = Self.background(rounded: false)
        w.contentView = bg
        windowBackground = bg
        window = w
        return w
    }

    // MARK: Keyboard

    private func handleKey(_ e: NSEvent) -> NSEvent? {
        guard store.isConnected, e.window === panel || e.window === window else { return e }
        Hovercard.shared.hide()
        if e.window?.firstResponder is NSTextView { return e } // typing a comment
        if e.modifierFlags.contains(.command) {
            if e.charactersIgnoringModifiers == "w", mode == .detached { attach(show: false); return nil }
            // ⌘↑: back to the top of the list, unless the article has focus (it scrolls itself).
            if e.keyCode == 126, !Self.isInWebView(e.window?.firstResponder) {
                scrollToTop()
                return nil
            }
            return e
        }
        switch e.keyCode {
        case 53: // esc
            if mode == .attached { showDetail ? closeDetail() : hidePanel() } else { closeDetail() }
            return nil
        case 125: move(1); return nil   // ↓
        case 126: move(-1); return nil  // ↑
        case 123: return switchFeed(-1) ? nil : e // ←
        case 124: return switchFeed(1) ? nil : e  // →
        default: break
        }
        switch e.charactersIgnoringModifiers {
        case "j": move(1); return nil
        case "k": move(-1); return nil
        case "o": openSelectedInBrowser(); return nil
        case "s":
            guard section == .reader, let post = selectedPost else { return e }
            reader.toggleSave(post)
            return nil
        case "l":
            guard section == .reader, let post = selectedPost, reader.canLike(post) else { return e }
            Task { await reader.toggleLike(post) }
            return nil
        default: return e
        }
    }

    // MARK: Helpers

    private static func isInWebView(_ responder: NSResponder?) -> Bool {
        var view = responder as? NSView
        while let v = view {
            if v is WKWebView { return true }
            view = v.superview
        }
        return false
    }

    private func animate(_ window: NSWindow, to frame: NSRect, alpha: CGFloat? = nil,
                         duration: TimeInterval, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
            window.animator().setFrame(frame, display: true)
            if let alpha { window.animator().alphaValue = alpha }
        }, completionHandler: {
            MainActor.assumeIsolated { completion?() }
        })
    }

    private func move(_ view: NSView, to container: NSView) {
        view.removeFromSuperview()
        embed(view, in: container)
    }

    private func embed(_ view: NSView, in container: NSView) {
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
    }

    private static func background(rounded: Bool) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        if rounded {
            // Stretchable rounded mask: clips the blur and gives the shadow its shape.
            let r: CGFloat = 16
            let mask = NSImage(size: NSSize(width: r * 2 + 1, height: r * 2 + 1), flipped: false) { rect in
                NSColor.black.setFill()
                NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
                return true
            }
            mask.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
            mask.resizingMode = .stretch
            v.maskImage = mask
        }
        return v
    }
}
