import AppKit
import Foundation

struct Note: Decodable, Identifiable {
    struct Range: Decodable {
        let type: String?
        let indices: [Int]?
        let url: String?
    }
    struct Media: Decodable { let url: String? }
    struct Block: Decodable {
        let text: String?
        let ranges: [Range]?
        let media: [Media]?
    }
    struct Meta: Decodable {
        struct IDs: Decodable { let site: Int?; let post: Int?; let comment: Int? }
        let ids: IDs?
    }
    enum Kind { case mention, comment, like, follow, other }

    let id: Int
    let type: String?
    var read: Int?
    let timestamp: String?
    let icon: String?
    let url: String?
    let subject: [Block]?
    let body: [Block]?
    let meta: Meta?

    var isUnread: Bool { (read ?? 1) == 0 }
    var date: Date? { timestamp.flatMap { ISO8601DateFormatter().date(from: $0) } }
    var excerpt: String? { subject?.dropFirst().first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var headline: String { subject?.first?.text ?? "" }
    private func span(_ type: String) -> NSRange? {
        guard let r = subject?.first?.ranges?.first(where: { $0.type == type }),
              let i = r.indices, i.count == 2, i[1] <= (headline as NSString).length else { return nil }
        return NSRange(location: i[0], length: i[1] - i[0])
    }

    /// "Jeff Golenski"
    var actor: String? { span("user").map { (headline as NSString).substring(with: $0) } }
    /// "A4A Weekly Product Progress Report…"
    var target: String? { span("post").map { (headline as NSString).substring(with: $0) } }
    /// "mentioned you on" — whatever sits between the actor and the post.
    var action: String {
        let ns = headline as NSString
        let start = span("user").map { $0.location + $0.length } ?? 0
        let end = span("post")?.location ?? ns.length
        guard end >= start else { return headline }
        return ns.substring(with: NSRange(location: start, length: end - start))
            .trimmingCharacters(in: .whitespaces)
    }

    var kind: Kind {
        switch type {
        case "automattcher": return .mention
        case "comment": return action.contains("mention") ? .mention : .comment
        case "like", "comment_like": return .like
        case "follow", "subscriber": return .follow
        default: return .other
        }
    }

    /// People in the body (likers, followers) as (name, avatar).
    var people: [(name: String, avatar: String?)] {
        (body ?? []).compactMap { b in
            guard b.ranges?.first?.type == "user", let name = b.text, b.ranges?.count == 1 else { return nil }
            return (name, b.media?.first?.url)
        }
    }
}

@MainActor
final class Store: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published private(set) var token: String? = Credentials.get("token")

    /// True when a token we had stopped working (expired or revoked), so setup says "reconnect".
    @Published private(set) var sessionExpired = false

    var unreadCount: Int { notes.filter(\.isUnread).count }
    var isConnected: Bool { token != nil }

    /// Words to highlight in the reader: @username, full name, first name.
    private(set) var mentionTerms: [String] = []
    private var pages: [Int: String] = [:]

    private let oauth = OAuth()
    private var timer: Timer?

    init() {
        // Left over from older builds: the code-exchange secret and a user-entered app ID.
        Credentials.set("clientSecret", nil)
        Credentials.set("clientID", nil)
        if let expires = Credentials.get("tokenExpires").flatMap(Double.init),
           Date(timeIntervalSince1970: expires) < .now {
            expireSession()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
        Task { await refresh() }
    }

    // MARK: Auth

    func connect() async {
        error = nil
        do {
            let t = try await oauth.authorize()
            Credentials.set("token", t.value)
            Credentials.set("tokenExpires", t.expires.map { String($0.timeIntervalSince1970) })
            sessionExpired = false
            token = t.value
            NSApp.activate(ignoringOtherApps: true)
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signOut() {
        Credentials.set("token", nil)
        Credentials.set("tokenExpires", nil)
        token = nil
        notes = []
        pages = [:]
    }

    private func expireSession() {
        signOut()
        sessionExpired = true
    }

    // MARK: API

    func refresh() async {
        guard token != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            struct Response: Decodable { let notes: [Note] }
            let data = try await request("notifications/?number=40&fields=id,type,read,timestamp,icon,url,subject,body,meta")
            notes = try JSONDecoder().decode(Response.self, from: data).notes
            error = nil
            if mentionTerms.isEmpty { await loadMe() }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadMe() async {
        struct Me: Decodable { let username: String; let display_name: String }
        guard let data = try? await request("me?fields=username,display_name"),
              let me = try? JSONDecoder().decode(Me.self, from: data) else { return }
        var terms = ["@" + me.username, me.display_name]
        if let first = me.display_name.split(separator: " ").first, first.count > 2 { terms.append(String(first)) }
        mentionTerms = terms
    }

    func openInBrowser(_ note: Note) {
        if let s = note.url, let url = URL(string: s) { NSWorkspace.shared.open(url) }
    }

    func markRead(_ note: Note) {
        guard note.isUnread else { return }
        Task { await markRead([note.id]) }
    }

    func markAllRead() async {
        await markRead(notes.filter(\.isUnread).map(\.id))
    }

    /// Flips the dots locally right away, then tells WordPress.com.
    private func markRead(_ ids: [Int]) async {
        guard !ids.isEmpty else { return }
        for i in notes.indices where ids.contains(notes[i].id) { notes[i].read = 1 }
        let counts = Dictionary(uniqueKeysWithValues: ids.map { ("\($0)", 1) })
        let body = try? JSONSerialization.data(withJSONObject: ["counts": counts])
        _ = try? await request("notifications/read", method: "POST", body: body)
    }

    // MARK: Reader

    /// Full HTML page for the reader, fetched from the post/comment the note points at.
    func page(for note: Note) async -> String {
        if let cached = pages[note.id] { return cached }
        let html = await buildPage(for: note)
        pages[note.id] = html
        return html
    }

    func prefetch(_ note: Note) {
        guard pages[note.id] == nil else { return }
        Task { _ = await page(for: note) }
    }

    private struct Author: Decodable { let name: String?; let avatar_URL: String? }
    private struct Post: Decodable { let title: String?; let content: String?; let date: String?; let URL: String?; let author: Author? }
    private struct Comment: Decodable {
        struct Parent: Decodable { let title: String? }
        let content: String?; let date: String?; let URL: String?; let author: Author?; let post: Parent?
    }

    /// "a4ateam" from https://a4ateam.wordpress.com/…
    private static func host(_ url: String?) -> String {
        url.flatMap { URL(string: $0)?.host }?.replacingOccurrences(of: ".wordpress.com", with: "") ?? "Site"
    }

    private func buildPage(for note: Note) async -> String {
        let ids = note.meta?.ids
        let likers = note.kind == .like ? note.people : []

        if let site = ids?.site, let comment = ids?.comment,
           let data = try? await request("sites/\(site)/comments/\(comment)?fields=content,date,URL,author,post"),
           let c = try? JSONDecoder().decode(Comment.self, from: data) {
            return ReaderPage.html(
                eyebrow: nil, title: c.post?.title ?? note.target ?? "",
                author: c.author?.name, avatar: c.author?.avatar_URL, date: c.date, url: c.URL ?? note.url,
                likers: likers, content: c.content ?? "", terms: mentionTerms,
                eyebrowHTML: "Comment on " + ReaderPage.siteLink(site, label: Self.host(c.URL ?? note.url)))
        }

        if let site = ids?.site, let post = ids?.post, note.kind != .like,
           let data = try? await request("sites/\(site)/posts/\(post)?fields=title,content,date,URL,author"),
           let p = try? JSONDecoder().decode(Post.self, from: data) {
            return ReaderPage.html(
                eyebrow: nil, title: p.title ?? "", author: p.author?.name, avatar: p.author?.avatar_URL,
                date: p.date, url: p.URL ?? note.url, likers: [], content: p.content ?? "", terms: mentionTerms,
                eyebrowHTML: ReaderPage.siteLink(site, label: Self.host(p.URL ?? note.url)))
        }

        // Likes on a post, follows, achievements: the note itself is the whole story.
        let text = (note.body ?? []).filter { $0.ranges?.first?.type != "user" || $0.ranges?.count != 1 }
            .compactMap(\.text).map { "<p>\(ReaderPage.escape($0))</p>" }.joined()
        return ReaderPage.html(
            eyebrow: [note.actor, note.action].compactMap { $0 }.joined(separator: " "),
            title: ReaderPage.escape(note.target ?? note.subject?.first?.text ?? ""),
            author: nil, avatar: nil, date: note.timestamp, url: note.url,
            likers: likers, content: text, terms: mentionTerms)
    }

    func request(_ path: String, version: String = "v1.1", method: String = "GET", body: Data? = nil) async throws -> Data {
        var req = URLRequest(url: URL(string: "https://public-api.wordpress.com/rest/\(version)/\(path)")!)
        req.httpMethod = method
        req.setValue("Bearer \(token ?? "")", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        // Expired/revoked tokens come back as 400 or 401 "invalid_token". Don't sign out on
        // other errors: a 403 "unauthorized" just means a private P2 you can't read.
        if let http = response as? HTTPURLResponse, [400, 401].contains(http.statusCode),
           let err = try? JSONDecoder().decode([String: String].self, from: data)["error"],
           err == "invalid_token" || http.statusCode == 401 {
            expireSession()
            throw OAuthError.denied("Your WordPress.com session expired.")
        }
        // Reads fall back on empty results; writes need to say what went wrong.
        if method != "GET", let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let err = try? JSONDecoder().decode([String: String].self, from: data)
            throw APIError(message: err?["message"] ?? "WordPress.com returned an error (\(http.statusCode)).")
        }
        return data
    }
}

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
