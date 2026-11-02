import AppKit
import SwiftUI

/// Demo mode, for the website's drift check (`tools/drift/check.sh`).
///
/// `DISPATCH_DEMO=<site/demo-data.json>` answers every WordPress.com request from the website
/// demo's made-up people and posts, and keeps sign-in, saves and settings in a throwaway folder.
/// `DISPATCH_RENDER=<folder>` also draws each scene the website shows, offscreen, into
/// `<scene>.png`, records where every `driftTag` landed in `<scene>.json`, then quits.
/// Neither touches the network, the menu bar or the real app's data.
enum Demo {
    static let dataURL = ProcessInfo.processInfo.environment["DISPATCH_DEMO"].map { URL(fileURLWithPath: $0) }
    static let renderURL = ProcessInfo.processInfo.environment["DISPATCH_RENDER"].map { URL(fileURLWithPath: $0) }
    static var isOn: Bool { dataURL != nil }
    static var isRendering: Bool { renderURL != nil }

    /// Stands in for `~/Library/Application Support/Dispatch`.
    static let directory: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dispatch-demo-\(getpid())", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// The website's scenes (`SCENES` in site/sim.js). Keep the two lists in step.
    static let scenes = ["notifications", "note-open", "comments-open", "comments-full", "reply-open", "reader", "reader-post", "xposts", "later"]
}

// MARK: - Made-up WordPress.com

/// Turns demo-data.json into the API responses the stores already know how to read, so demo
/// mode runs the app's real decoding and layout code.
@MainActor
final class DemoAPI {
    static let shared = DemoAPI()

    private struct Person: Decodable { let name: String; let color: String }
    private struct Site: Decodable {
        let id: Int; let name: String; let host: String; let color: String
        let about: String?; let subs: Int?; let posts: Int?; let p2: Bool?
    }
    private struct Comment: Decodable { let id: Int; let who: String; let text: String; let ago: String; let likes: Int; let depth: Int }
    private struct XPost: Decodable { let from: String; let to: String }
    private struct Post: Decodable {
        let id: Int; let site: String; let title: String; let author: String; let ago: String; let read: String
        let excerpt: String; let body: [String]; let likes: Int; let comments: [Comment]; let xpost: XPost?; let views: String?
    }
    private struct NoteData: Decodable {
        let num: Int; let kind: String; let who: String; let action: String
        let post: String?; let site: String?; let comment: Int?; let ago: String; let text: String
        let unread: Bool; let people: [String]?
    }
    private struct Data_: Decodable {
        struct Me: Decodable { let name: String; let handle: String }
        let me: Me; let people: [String: Person]; let sites: [String: Site]
        let posts: [String: Post]; let notes: [NoteData]; let feeds: [String: [String]]
    }

    private let data: Data_?
    private let now = Date()

    private init() {
        data = Demo.dataURL.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(Data_.self, from: $0) }
    }

    func respond(_ path: String, method: String) -> Data {
        guard let d = data, method == "GET" else { return json([:]) }
        let route = path.split(separator: "?").first.map(String.init) ?? path
        let parts = route.split(separator: "/").map(String.init)

        switch route {
        case "me": return json(["username": d.me.handle, "display_name": d.me.name])
        case "notifications/": return json(["notes": d.notes.map(note)])
        case "read/following": return json(["posts": d.feeds["blogs", default: []].compactMap(readerPost)])
        case "read/a8c": return json(["posts": d.feeds["p2s", default: []].compactMap(readerPost)])
        case "read/saved": return json(["posts": [], "found": 0])
        case "read/saved/keys": return json(["keys": [], "total": 0])
        case "read/following/mine":
            return json(["subscriptions": d.sites.map { key, s in
                ["blog_ID": "\(s.id)", "name": s.name, "site_icon": icon(site: key), "is_wpforteams_site": s.p2 ?? false] as [String: Any]
            }])
        default: break
        }
        // read/sites/<id>/posts, read/sites/<id>
        if parts.count >= 3, parts[0] == "read", parts[1] == "sites", let (key, s) = site(id: parts[2]) {
            if parts.count == 4 {
                return json(["posts": d.posts.filter { $0.value.site == key && $0.value.xpost == nil }
                    .sorted { $0.value.id < $1.value.id }.compactMap { readerPost($0.key) }])
            }
            return json(["name": s.name, "description": s.about ?? "", "URL": "https://\(s.host)",
                         "subscribers_count": s.subs ?? 0, "post_count": s.posts ?? 0, "icon": ["img": icon(site: key)]])
        }
        // sites/<id>, sites/<id>/posts/<id>, sites/<id>/posts/<id>/replies, sites/<id>/comments/<id>
        if parts.first == "sites", parts.count >= 2, let (key, _) = site(id: parts[1]) {
            if parts.count == 2 { return json(["icon": ["img": icon(site: key)]]) }
            if parts.count >= 4, parts[2] == "posts", let (_, p) = post(id: parts[3]) {
                if parts.count == 5 { return json(["comments": comments(p)]) }
                return json(["title": p.title, "excerpt": p.excerpt, "content": html(p.body), "date": date(p.ago), "URL": url(p),
                             "author": author(p.author), "like_count": p.likes, "i_like": false])
            }
            if parts.count == 4, parts[2] == "comments", let id = Int(parts[3]),
               let (p, c) = d.posts.values.lazy.compactMap({ p in p.comments.first { $0.id == id }.map { (p, $0) } }).first {
                // A reply's parent is the closest comment above it, one level up.
                let i = p.comments.firstIndex { $0.id == c.id } ?? 0
                let parent = c.depth == 0 ? nil : p.comments[..<i].last { $0.depth == c.depth - 1 }
                return json(["content": "<p>\(ReaderPage.escape(c.text))</p>", "date": date(c.ago), "URL": url(p) + "#comment-\(c.id)",
                             "author": author(c.who), "post": ["ID": p.id, "title": p.title],
                             "parent": parent.map { ["ID": $0.id] as Any } ?? false])
            }
        }
        return json([:])
    }

    // MARK: Shapes

    private func note(_ n: NoteData) -> [String: Any] {
        let d = data!
        let p = n.post.flatMap { d.posts[$0] }
        let name = d.people[n.who]?.name ?? n.who
        // Follows name a site, not a post, as WordPress.com does.
        let target = p?.title ?? n.site.flatMap { d.sites[$0]?.name } ?? ""
        let headline = "\(name) \(n.action) \(target)"
        let start = (name + " " + n.action + " ").utf16.count
        var subject: [[String: Any]] = [[
            "text": headline,
            "ranges": [["type": "user", "indices": [0, name.utf16.count]],
                       ["type": p == nil ? "site" : "post", "indices": [start, start + target.utf16.count]]],
        ]]
        if !n.text.isEmpty { subject.append(["text": n.text]) }
        let commentID = n.comment ?? p?.comments.first { $0.who == n.who && $0.text == n.text }?.id
        var ids: [String: Any] = [:]
        if let site = (p?.site ?? n.site).flatMap({ d.sites[$0] }) { ids["site"] = site.id }
        if let p { ids["post"] = p.id }
        if let commentID, n.kind != "mention" || n.comment != nil { ids["comment"] = commentID }
        let type = switch n.kind {
        case "like": n.comment == nil ? "like" : "comment_like"
        case "follow": "follow"
        default: "comment"
        }
        return [
            "id": n.num, "type": type, "read": n.unread ? 0 : 1, "timestamp": date(n.ago),
            "icon": avatar(n.who), "url": p.map(url) ?? "", "subject": subject,
            "body": (n.people ?? []).map { who in
                let nm = d.people[who]?.name ?? who
                return ["text": nm, "ranges": [["type": "user", "indices": [0, nm.utf16.count]]], "media": [["url": avatar(who)]]] as [String: Any]
            },
            "meta": ["ids": ids],
        ]
    }

    private func readerPost(_ key: String) -> [String: Any]? {
        guard let d = data, let p = d.posts[key], let s = d.sites[p.site] else { return nil }
        let words = Int(p.read.split(separator: " ").first ?? "") ?? 1
        var out: [String: Any] = [
            "ID": p.id, "site_ID": s.id, "title": p.title, "URL": url(p), "date": date(p.ago),
            "excerpt": p.excerpt, "content": html(p.body), "site_name": s.name, "site_icon": ["img": icon(site: p.site)],
            "author": author(p.author), "word_count": words * 230, "like_count": p.likes, "i_like": false,
            "discussion": ["comment_count": p.comments.count],
        ]
        if let v = p.views { out["views"] = v }
        // An x-post is a snippet on the destination P2 that points at the original.
        if let x = p.xpost, let to = d.sites[x.to], let from = d.sites[x.from] {
            out["ID"] = p.id + 10_000
            out["site_ID"] = to.id
            out["site_name"] = to.name
            out["site_icon"] = ["img": icon(site: x.to)]
            out["title"] = "X-post: \(p.title)"
            out["URL"] = "https://\(to.host)/xpost-\(p.id)"
            out["content"] = "<p>X-post from <a title=\"\(from.name)\" href=\"\(url(p))\">\(from.name)</a>: \(ReaderPage.escape(p.title))</p>"
            out["metadata"] = [["key": "xpost_origin", "value": "\(from.id):\(p.id)"],
                               ["key": "_xpost_original_permalink", "value": url(p)]]
        }
        return out
    }

    private func comments(_ p: Post) -> [[String: Any]] {
        var parents: [Int: Int] = [:] // depth → last comment at that depth
        return p.comments.map { c in
            parents[c.depth] = c.id
            var out: [String: Any] = ["ID": c.id, "author": author(c.who), "date": date(c.ago),
                                      "content": "<p>\(ReaderPage.escape(c.text))</p>", "like_count": c.likes, "i_like": false]
            out["parent"] = c.depth > 0 ? ["ID": parents[c.depth - 1] ?? 0] as Any : false
            return out
        }
    }

    // MARK: Helpers

    private func site(id: String) -> (String, Site)? {
        data?.sites.first { "\($0.value.id)" == id }.map { ($0.key, $0.value) }
    }
    private func post(id: String) -> (String, Post)? {
        data?.posts.first { "\($0.value.id)" == id }.map { ($0.key, $0.value) }
    }
    private func author(_ who: String) -> [String: Any] {
        ["name": data?.people[who]?.name ?? who, "avatar_URL": avatar(who)]
    }
    private func url(_ p: Post) -> String {
        "https://\(data?.sites[p.site]?.host ?? "example.com")/\(p.title.lowercased().filter { $0.isLetter || $0 == " " }.replacingOccurrences(of: " ", with: "-"))"
    }
    private func html(_ paragraphs: [String]) -> String {
        paragraphs.map { "<p>\(ReaderPage.escape($0))</p>" }.joined()
    }
    /// "2h" → two hours before the demo started, as WordPress.com's ISO 8601.
    private func date(_ ago: String) -> String {
        let n = Double(ago.dropLast()) ?? 0
        let unit: Double = switch ago.last { case "m": 60; case "h": 3600; case "d": 86_400; default: 0 }
        return ISO8601DateFormatter().string(from: now.addingTimeInterval(-n * unit))
    }
    private func json(_ object: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
    }

    // MARK: Pictures

    /// People and sites get the website's initials-on-color pictures, drawn once into the demo folder.
    private var drawn: Set<String> = []

    private func avatar(_ who: String) -> String {
        guard let p = data?.people[who] else { return "" }
        let letters = p.name.split(separator: " ").compactMap(\.first).map(String.init).joined()
        return picture("person-\(who)", letters, p.color, font: .systemFont(ofSize: 34, weight: .semibold))
    }
    private func icon(site key: String) -> String {
        guard let s = data?.sites[key] else { return "" }
        let letter = String(s.name.replacingOccurrences(of: "+", with: "").prefix(1)).uppercased()
        let rounded = NSFont.systemFont(ofSize: 44, weight: .semibold).fontDescriptor.withDesign(.rounded)
        return picture("site-\(key)", letter, s.color, font: rounded.flatMap { NSFont(descriptor: $0, size: 44) } ?? .systemFont(ofSize: 44))
    }

    private func picture(_ name: String, _ text: String, _ hex: String, font: NSFont) -> String {
        let file = Demo.directory.appendingPathComponent("\(name).png")
        if drawn.insert(name).inserted {
            let size = NSSize(width: 96, height: 96)
            let image = NSImage(size: size, flipped: false) { rect in
                let color = NSColor(hex: hex)
                NSGradient(starting: color.blended(withFraction: 0.18, of: .white) ?? color, ending: color)?.draw(in: rect, angle: -90)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
                let t = NSAttributedString(string: text, attributes: attrs)
                let ts = t.size()
                t.draw(at: NSPoint(x: (rect.width - ts.width) / 2, y: (rect.height - ts.height) / 2))
                return true
            }
            if let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: file)
            }
        }
        return file.absoluteString
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                  blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
}

// MARK: - Measuring

/// Where tagged views landed, in points from the panel's top-left. Filled only while rendering.
enum Drift {
    nonisolated(unsafe) static var frames: [String: CGRect] = [:]
    nonisolated(unsafe) static var owners: [String: UUID] = [:]
}

private struct DriftScopeKey: EnvironmentKey { static let defaultValue = "" }
extension EnvironmentValues {
    var driftScope: String {
        get { self[DriftScopeKey.self] }
        set { self[DriftScopeKey.self] = newValue }
    }
}

extension View {
    /// Names this view for the website's drift check, matching a `data-drift` name in site/sim.js.
    /// Inside a `driftScope` the name is prefixed ("row.2" + "icon"). Does nothing outside `DISPATCH_RENDER`.
    /// Geometry ignores `.offset`, so a view moved by one passes the same amount as `shift`.
    /// `rect` instead names a fixed rectangle inside this view.
    @ViewBuilder func driftTag(_ name: String, shift: CGSize = .zero, rect: CGRect? = nil) -> some View {
        if Demo.isRendering { modifier(DriftTag(name: name, shift: shift, rect: rect)) } else { self }
    }

    @ViewBuilder func driftScope(_ name: String) -> some View {
        if Demo.isRendering { environment(\.driftScope, name) } else { self }
    }
}

private struct DriftTag: ViewModifier {
    let name: String
    let shift: CGSize
    let rect: CGRect?
    @Environment(\.driftScope) private var scope
    @State private var id = UUID()

    func body(content: Content) -> some View {
        let key = scope.isEmpty ? name : "\(scope).\(name)"
        if name.isEmpty { content } else { tracked(content, key) }
    }

    private func tracked(_ content: Content, _ key: String) -> some View {
        // Window coordinates: the render window holds only the panel, so they're the panel's.
        // (A named coordinate space didn't reach into overlays.)
        content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
            let f = $0.offsetBy(dx: shift.width, dy: shift.height)
            Drift.frames[key] = rect.map { $0.offsetBy(dx: f.minX, dy: f.minY) } ?? f
            Drift.owners[key] = id
        }
        // Gone for good (a read row's dot), unless a newer copy of the view took the name over.
        .onDisappear { if Drift.owners[key] == id { Drift.frames[key] = nil } }
    }
}

// MARK: - Rendering

@MainActor
enum DemoRender {
    /// The website's panel is 548pt tall; match it so both lay out the same rows.
    static let height: CGFloat = 548

    static func run(_ c: PanelController) async {
        guard let out = Demo.renderURL else { return }
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        await c.store.refresh()

        for scene in Demo.scenes {
            await stage(scene, c)
            let width = c.listWidth + (c.showDetail ? c.detailWidth + 1 : 0)
            let host = NSHostingView(rootView: AnyView(
                RootView()
                    .environmentObject(c.store).environmentObject(c.reader).environmentObject(c)))
            host.appearance = NSAppearance(named: .aqua)
            host.frame = NSRect(x: 0, y: 0, width: width, height: height)
            // Never on screen: far off to the side, and see-through.
            let window = NSWindow(contentRect: NSRect(x: -30_000, y: -30_000, width: width, height: height),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.alphaValue = 0
            window.contentView = host
            window.orderFrontRegardless()
            Drift.frames = [:]
            try? await Task.sleep(for: .milliseconds(900)) // pictures load, comments arrive, springs settle
            host.layoutSubtreeIfNeeded()

            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                rep.size = host.bounds.size
                host.cacheDisplay(in: host.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent("\(scene).png"))
            }
            let frames = Drift.frames.mapValues { [$0.minX, $0.minY, $0.width, $0.height].map { ($0 * 10).rounded() / 10 } }
            let doc: [String: Any] = ["width": width, "height": height, "frames": frames]
            try? JSONSerialization.data(withJSONObject: doc, options: [.prettyPrinted, .sortedKeys])
                .write(to: out.appendingPathComponent("\(scene).json"))
            window.orderOut(nil)
            window.close()
        }
        try? FileManager.default.removeItem(at: Demo.directory)
    }

    /// Mirrors `SCENES` in site/sim.js.
    private static func stage(_ scene: String, _ c: PanelController) async {
        c.resetForDemo()
        Reminders.shared.all.map(\.id).forEach(Reminders.shared.cancel)
        await c.store.refresh() // fresh read/unread state
        let notes = c.store.notes
        switch scene {
        case "note-open": if let n = notes.first(where: { $0.id == 2 }) { c.select(n) }
        case "reply-open": if let n = notes.first(where: { $0.id == 4 }) { c.select(n) }
        case "later":
            // A notification for tomorrow morning and a post in three hours, as the site's scene has.
            let when = Reminders.choices()
            if let n = notes.first(where: { $0.id == 2 }), let t = when.first(where: { $0.title == "Tomorrow Morning" }) {
                Reminders.shared.remind(n, at: t.due)
            }
            c.reader.show(.blogs)
            await c.reader.refresh()
            if let p = c.reader.posts.first(where: { $0.title == "The case for software that waits" }) {
                Reminders.shared.remind(p, at: when[1].due)
            }
            c.switchSection(.later)
        case "comments-open", "comments-full":
            if let n = notes.first(where: { $0.id == 1 }) { c.select(n) }
            c.commentsOpen = true
            c.commentsExpanded = scene == "comments-full"
        case "reader", "reader-post", "xposts":
            c.switchSection(.reader)
            c.reader.show(scene == "xposts" ? .p2s : .blogs)
            await c.reader.refresh()
            if scene == "reader-post", let p = c.reader.posts.first(where: { $0.title == "The case for software that waits" }) { c.select(p) }
            if scene == "xposts", let p = c.reader.posts.first(where: \.isXPost) { c.select(p) }
        default: break
        }
        try? await Task.sleep(for: .milliseconds(200))
    }
}
