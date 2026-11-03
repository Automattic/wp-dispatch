import AppKit
import SwiftUI

// Hovercards, like P2's: rest the pointer on an avatar or a site icon and a small card
// opens beside it. The card lives in its own non-activating panel, so the list keeps
// keyboard focus (j/k still work) and nothing gets clipped by the panel's edges.

extension View {
    /// Opens `card` beside this view after a short hover. `edge` is the side it prefers.
    func hovercard<Card: View>(edge: Edge = .leading, @ViewBuilder _ card: @escaping () -> Card) -> some View {
        modifier(HovercardAnchor(edge: edge, card: card))
    }
}

/// Gravatar hash from an avatar URL (`…/avatar/<hash>?s=96`), when it is one.
func gravatarHash(_ url: String?) -> String? {
    guard let url, url.contains("gravatar.com/avatar/"),
          let r = url.range(of: #"/avatar/[0-9a-f]{32,64}"#, options: .regularExpression) else { return nil }
    return String(url[r].dropFirst("/avatar/".count))
}

private struct HovercardAnchor<Card: View>: ViewModifier {
    let edge: Edge
    let card: () -> Card
    @EnvironmentObject var reader: ReaderStore
    @EnvironmentObject var c: PanelController
    @State private var anchor = Hovercard.Anchor()

    func body(content: Content) -> some View {
        content
            .background(AnchorView(anchor: anchor))
            .onHover { inside in
                if inside {
                    Hovercard.shared.hover(AnyView(card().environmentObject(reader).environmentObject(c)),
                                           from: anchor, edge: edge)
                } else {
                    Hovercard.shared.leave(anchor)
                }
            }
            .onDisappear { Hovercard.shared.leave(anchor) }
    }

    /// Gives the controller the AppKit view, so it can find the anchor on screen.
    private struct AnchorView: NSViewRepresentable {
        let anchor: Hovercard.Anchor
        func makeNSView(context: Context) -> NSView {
            let v = NSView()
            anchor.view = v
            return v
        }
        func updateNSView(_ view: NSView, context: Context) { anchor.view = view }
    }
}

@MainActor
final class Hovercard {
    static let shared = Hovercard()

    /// What a card opens beside: a view, or a rect inside it (an author in the article's web view).
    final class Anchor {
        weak var view: NSView?
        var rect: NSRect?
    }

    private final class CardPanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    /// Tracks the pointer over the card itself, so moving onto it keeps it open.
    private final class TrackingView: NSView {
        var onHover: (Bool) -> Void = { _ in }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                           owner: self))
        }
        override func mouseEntered(with event: NSEvent) { onHover(true) }
        override func mouseExited(with event: NSEvent) { onHover(false) }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }

    private var panel: CardPanel?
    private var hosting: NSHostingView<AnyView>?
    private weak var current: Anchor?
    private var edge: Edge = .leading
    private var pending: Task<Void, Never>?
    private var hiding: Task<Void, Never>?
    private var overCard = false

    private var isShowing: Bool { panel?.isVisible == true }

    func hover(_ card: AnyView, from anchor: Anchor, edge: Edge) {
        NSLog("HC hover")
        hiding?.cancel()
        pending?.cancel()
        let delay: Duration = isShowing ? .milliseconds(120) : .milliseconds(550)
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.present(card, at: anchor, edge: edge)
        }
    }

    func leave(_ anchor: Anchor) {
        if current == nil || current === anchor { pending?.cancel() }
        guard current === anchor else { return }
        scheduleHide()
    }

    func hide() {
        pending?.cancel()
        hiding?.cancel()
        panel?.orderOut(nil)
        current = nil
        overCard = false
    }

    /// The card's size changes as its data arrives; keep it pinned beside the anchor.
    func fit(_ size: CGSize) {
        guard isShowing, let panel, let rect = current.flatMap(screenRect) else { return }
        panel.setFrame(frame(for: size, beside: rect, on: panel.screen), display: true)
        panel.invalidateShadow()
    }

    private func scheduleHide() {
        hiding?.cancel()
        hiding = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, let self, !self.overCard else { return }
            self.hide()
        }
    }

    private func present(_ card: AnyView, at anchor: Anchor, edge: Edge) {
        NSLog("HC present view=%@ win=%@", String(describing: anchor.view), String(describing: anchor.view?.window))
        guard let rect = screenRect(anchor) else { return }
        NSLog("HC rect %@", NSStringFromRect(rect))
        let panel = self.panel ?? makePanel()
        current = anchor
        self.edge = edge
        hosting?.rootView = card
        let size = hosting?.fittingSize ?? CGSize(width: 280, height: 120)
        let screen = anchor.view?.window?.screen
        panel.setFrame(frame(for: size, beside: rect, on: screen), display: true)
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless() // the app is usually not active (menu bar app)
            NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }
        }
        panel.invalidateShadow()
    }

    private func screenRect(_ anchor: Anchor) -> NSRect? {
        guard let view = anchor.view, let window = view.window, window.isVisible else { return nil }
        return window.convertToScreen(view.convert(anchor.rect ?? view.bounds, to: nil))
    }

    /// Beside the anchor on the preferred side, flipped or nudged to stay on screen.
    private func frame(for size: CGSize, beside a: NSRect, on screen: NSScreen?) -> NSRect {
        let gap: CGFloat = 8
        let vis = (screen ?? NSScreen.main)?.visibleFrame ?? .infinite
        var o: NSPoint
        switch edge {
        case .leading, .trailing:
            let left = NSPoint(x: a.minX - gap - size.width, y: a.maxY - size.height + 6)
            let right = NSPoint(x: a.maxX + gap, y: left.y)
            o = edge == .leading ? (left.x >= vis.minX ? left : right) : (right.x + size.width <= vis.maxX ? right : left)
        case .top, .bottom:
            let above = NSPoint(x: a.minX - 6, y: a.maxY + gap)
            let below = NSPoint(x: above.x, y: a.minY - gap - size.height)
            o = edge == .top ? (above.y + size.height <= vis.maxY ? above : below) : (below.y >= vis.minY ? below : above)
        }
        o.x = min(max(o.x, vis.minX + 4), vis.maxX - size.width - 4)
        o.y = min(max(o.y, vis.minY + 4), vis.maxY - size.height - 4)
        return NSRect(origin: o, size: size)
    }

    private func makePanel() -> CardPanel {
        let p = CardPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.transient, .ignoresCycle]

        let blur = NSVisualEffectView()
        blur.material = .popover
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 12
        blur.layer?.masksToBounds = true

        let tracking = TrackingView()
        tracking.onHover = { [weak self] inside in
            guard let self else { return }
            self.overCard = inside
            if inside { self.hiding?.cancel() } else { self.scheduleHide() }
        }
        let host = NSHostingView(rootView: AnyView(EmptyView()))
        for (child, parent) in [(blur, tracking as NSView), (host, blur)] {
            child.translatesAutoresizingMaskIntoConstraints = false
            parent.addSubview(child)
            NSLayoutConstraint.activate([
                child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
                child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
                child.topAnchor.constraint(equalTo: parent.topAnchor),
                child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            ])
        }
        p.contentView = tracking
        panel = p
        hosting = host
        return p
    }
}

// MARK: - Cards

/// Shared frame: fixed width, reports its height so the panel can follow it.
private struct CardFrame<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(14)
            .frame(width: 290, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { Hovercard.shared.fit($0) }
    }
}

private struct CardLink: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 11.5, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A person, from their Gravatar profile. Falls back to what the row already knows.
struct PersonCard: View {
    @EnvironmentObject var reader: ReaderStore
    @EnvironmentObject var c: PanelController
    let avatar: String?
    let name: String?
    @State private var profile: ReaderStore.Profile?
    @State private var loaded = false

    var body: some View {
        CardFrame {
            HStack(alignment: .center, spacing: 12) {
                AsyncImage(url: avatar.flatMap { URL(string: $0.replacingOccurrences(of: #"s=\d+"#, with: "s=160", options: .regularExpression)) }) { img in
                    img.resizable().scaledToFill()
                } placeholder: { Color.secondary.opacity(0.15) }
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(profile?.display_name.nonEmpty ?? name ?? "Someone")
                            .font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        if let pronouns = profile?.pronouns.nonEmpty {
                            Text(pronouns).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    if let work = [profile?.job_title.nonEmpty, profile?.company.nonEmpty].compactMap({ $0 }).joined(separator: ", ").nonEmpty {
                        Text(work).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if let location = profile?.location.nonEmpty {
                        Label(location, systemImage: "mappin").font(.system(size: 11)).foregroundStyle(.secondary)
                            .labelStyle(TightLabel()).lineLimit(1)
                    }
                }
            }
            if let about = profile?.description.nonEmpty {
                Text(about).font(.system(size: 12)).lineSpacing(2).lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !loaded {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity)
            }
            if let url = profile?.profile_url.flatMap(URL.init(string:)) {
                CardLink("View profile") { open(url) }
            }
        }
        .task {
            if let hash = gravatarHash(avatar) { profile = await reader.profile(hash: hash) }
            loaded = true
        }
    }

    private func open(_ url: URL) {
        Hovercard.shared.hide()
        openLink(url)
        if c.mode == .attached { c.hidePanel() }
    }
}

/// A site, from the Reader. Private P2s you can't see just show their name and icon.
struct SiteCard: View {
    @EnvironmentObject var reader: ReaderStore
    @EnvironmentObject var c: PanelController
    let id: Int
    let name: String
    let icon: String?
    @State private var info: ReaderStore.SiteInfo?
    @State private var loaded = false

    var body: some View {
        let title = info?.name.nonEmpty?.plainText ?? name.plainText
        CardFrame {
            HStack(alignment: .center, spacing: 12) {
                SiteIcon(url: info?.icon?.img ?? icon, name: title, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                    if let host = info?.URL.flatMap(URL.init(string:))?.host() {
                        Text(host.replacingOccurrences(of: "www.", with: ""))
                            .font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            if let about = info?.description.nonEmpty?.plainText {
                Text(about).font(.system(size: 12)).lineSpacing(2).lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !loaded {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity)
            }
            if let stats = [info?.subscribers_count.map { "\($0.formatted()) subscribers" },
                            info?.post_count.map { "\($0.formatted()) posts" }].compactMap({ $0 }).joined(separator: " · ").nonEmpty {
                Text(stats).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                CardLink("Read") {
                    Hovercard.shared.hide()
                    c.openSite(id, name: title)
                }
                if let url = info?.URL.flatMap(URL.init(string:)) {
                    CardLink("Visit site") {
                        Hovercard.shared.hide()
                        openLink(url)
                        if c.mode == .attached { c.hidePanel() }
                    }
                }
            }
        }
        .task {
            info = await reader.siteInfo(id)
            loaded = true
        }
    }
}

private struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.icon.font(.system(size: 9)); configuration.title }
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? { self.flatMap { $0.isEmpty ? nil : $0 } }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
