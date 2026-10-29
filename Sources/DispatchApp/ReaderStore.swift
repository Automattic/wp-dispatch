import AppKit
import Foundation

struct ReaderPost: Codable, Identifiable, Hashable {
    struct Author: Codable { let name: String?; let avatar_URL: String? }
    struct Icon: Codable { let img: String? }
    struct Meta: Codable {
        let key: String?
        let value: String?
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            key = try? c.decode(String.self, forKey: .key)
            value = try? c.decode(String.self, forKey: .value)
        }
    }

    let postID: Int
    let site_ID: Int
    let title: String?
    let URL: String?
    let date: String?
    let excerpt: String?
    let content: String?
    let site_name: String?
    let site_icon: Icon?
    let author: Author?
    let word_count: Int?
    /// RSS-only blogs: `site_ID` is really the feed ID and the site endpoints don't apply.
    let is_external: Bool?
    let metadata: [Meta]?
    let like_count: Int?
    let i_like: Bool?

    var isExternal: Bool { is_external ?? false }

    private enum CodingKeys: String, CodingKey {
        case postID = "ID", site_ID, title, URL, date, excerpt, content, site_name, site_icon, author, word_count, is_external, metadata, like_count, i_like
    }

    // The Reader API is loose with types (string IDs, `[]` for a missing icon), so decode leniently.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func int(_ k: CodingKeys) -> Int? {
            (try? c.decode(Int.self, forKey: k)) ?? (try? c.decode(String.self, forKey: k)).flatMap { Int($0) }
        }
        postID = int(.postID) ?? 0
        site_ID = int(.site_ID) ?? 0
        title = try? c.decode(String.self, forKey: .title)
        URL = try? c.decode(String.self, forKey: .URL)
        date = try? c.decode(String.self, forKey: .date)
        excerpt = try? c.decode(String.self, forKey: .excerpt)
        content = try? c.decode(String.self, forKey: .content)
        site_name = try? c.decode(String.self, forKey: .site_name)
        site_icon = try? c.decode(Icon.self, forKey: .site_icon)
        author = try? c.decode(Author.self, forKey: .author)
        word_count = int(.word_count)
        is_external = try? c.decode(Bool.self, forKey: .is_external)
        metadata = try? c.decode([Meta].self, forKey: .metadata)
        like_count = int(.like_count)
        i_like = (try? c.decode(Bool.self, forKey: .i_like)) ?? int(.i_like).map { $0 != 0 } // sometimes 0/1
    }

    // MARK: X-posts
    // A P2 author can "+handle" another P2 to drop a snippet of their post there.
    // The snippet carries `xpost_origin` ("siteID:postID") and the original permalink.

    private func meta(_ key: String) -> String? { metadata?.first { $0.key == key }?.value }

    var xpostOrigin: (site: Int, post: Int)? {
        let parts = meta("xpost_origin")?.split(separator: ":").compactMap { Int($0) } ?? []
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }
    var originalURL: String? { meta("_xpost_original_permalink") }
    var isXPost: Bool { xpostOrigin != nil || originalURL != nil }

    /// "+researchp2" and "A8c Research", from the snippet's "X-post from <a title=…>+handle</a>".
    var xpostSource: (handle: String, name: String?) {
        if let content, let m = content.range(of: #"X-post from <a [^>]*>[^<]*</a>"#, options: .regularExpression) {
            let tag = String(content[m])
            let handle = tag.replacingOccurrences(of: #"^.*>([^<]*)</a>$"#, with: "$1", options: .regularExpression).plainText
            let name = tag.range(of: #"title="[^"]*""#, options: .regularExpression)
                .map { String(tag[$0].dropFirst(7).dropLast()).plainText }
            if !handle.isEmpty { return (handle, name) }
        }
        return (Self.handle(originalURL) ?? "another P2", nil)
    }
    var destinationHandle: String { Self.handle(URL) ?? site_name ?? "" }
    var xpostTitle: String {
        (title ?? "").plainText.replacingOccurrences(of: #"^X-post:\s*"#, with: "", options: .regularExpression)
    }

    private static func handle(_ url: String?) -> String? {
        url.flatMap { Foundation.URL(string: $0)?.host?.split(separator: ".").first }.map { "+\($0)" }
    }

    var id: String { "\(site_ID)-\(postID)" }
    var dateValue: Date? { date.flatMap { ISO8601DateFormatter().date(from: $0) } }
    var readingTime: String? { word_count.map { $0 < 120 ? "Quick read" : "\(max(1, $0 / 230)) min" } }

    static func == (a: ReaderPost, b: ReaderPost) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct PostComment: Decodable, Identifiable {
    struct Author: Decodable { let name: String?; let avatar_URL: String? }

    let id: Int
    let author: Author?
    let date: String?
    let parentID: Int?
    /// Plain text with paragraph breaks kept; computed once since rows re-render a lot.
    let text: String
    var depth = 0
    var likeCount: Int
    var iLike: Bool

    var dateValue: Date? { date.flatMap { ISO8601DateFormatter().date(from: $0) } }
    /// First ~140 characters on one line, for the closed bubble strip.
    var snippet: String { String(text.replacingOccurrences(of: "\n", with: " ").prefix(140)) }

    private enum CodingKeys: String, CodingKey { case id = "ID", author, date, content, parent, like_count, i_like }
    private enum ParentKeys: String, CodingKey { case id = "ID" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        author = try? c.decode(Author.self, forKey: .author)
        date = try? c.decode(String.self, forKey: .date)
        // `parent` is `false` for top-level comments, an object for replies.
        parentID = (try? c.nestedContainer(keyedBy: ParentKeys.self, forKey: .parent))
            .flatMap { try? $0.decode(Int.self, forKey: .id) }
        text = ((try? c.decode(String.self, forKey: .content)) ?? "").commentText
        likeCount = (try? c.decode(Int.self, forKey: .like_count)) ?? 0
        iLike = (try? c.decode(Bool.self, forKey: .i_like)) ?? false
    }
}

struct ReaderSite: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
    let icon: String?
    var isP2 = false
    var isFeed = false
}

/// Followed blogs, Automattic P2s and saved posts.
/// Saves are local to this app (WordPress.com has no API for them); likes are real WordPress.com likes.
@MainActor
final class ReaderStore: ObservableObject {
    enum Feed: Hashable { case blogs, p2s, saved, site(Int, isFeed: Bool) }

    @Published private(set) var feed: Feed = .blogs
    @Published private(set) var posts: [ReaderPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var saved: [ReaderPost] = []
    @Published private(set) var sites: [Int: ReaderSite] = [:]
    /// Icons for sites we don't follow (x-post origins), looked up on demand.
    @Published private(set) var extraIcons: [Int: String] = [:]
    private var iconLookups: Set<Int> = []
    /// Where "back" goes from a single-site feed.
    private(set) var previousFeed: Feed = .blogs

    private let store: Store
    private var cache: [Feed: Page] = [:]
    private var pages: [String: String] = [:]
    private struct Page { var posts: [ReaderPost]; var before: String?; var done: Bool }

    init(store: Store) {
        self.store = store
        let saved = Self.loadFile()
        self.saved = saved.saved
    }

    // MARK: Feeds

    func show(_ feed: Feed) {
        if case .site = feed, !isSiteFeed { previousFeed = self.feed }
        self.feed = feed
        posts = feed == .saved ? saved : cache[feed]?.posts ?? []
        Task { await refresh() }
    }

    /// False until the current feed's first page arrives (so we show a spinner, not "No posts").
    var hasLoaded: Bool { feed == .saved || cache[feed] != nil }

    var isSiteFeed: Bool { if case .site = feed { return true } else { return false } }

    func refresh() async {
        if sites.isEmpty { await loadSubscriptions() }
        guard feed != .saved else { posts = saved; return }
        let feed = self.feed
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await fetch(feed, before: nil)
            cache[feed] = page
            if self.feed == feed { posts = page.posts }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadMore() async {
        let feed = self.feed
        guard !isLoading, feed != .saved, let current = cache[feed], !current.done else { return }
        isLoading = true
        defer { isLoading = false }
        guard let next = try? await fetch(feed, before: current.before) else { return }
        let known = Set(current.posts.map(\.id))
        let merged = current.posts + next.posts.filter { !known.contains($0.id) }
        cache[feed] = Page(posts: merged, before: next.before, done: next.done)
        if self.feed == feed { posts = merged }
    }

    private func fetch(_ feed: Feed, before: String?) async throws -> Page {
        struct Response: Decodable { let posts: [ReaderPost] }
        let paging = before.map { "&before=\($0.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0)" } ?? ""

        func get(_ path: String) async throws -> [ReaderPost] {
            let data = try await store.request("\(path)\(paging)", version: "v1.2")
            return try JSONDecoder().decode(Response.self, from: data).posts
        }

        let posts: [ReaderPost]
        switch feed {
        case .blogs: posts = try await get("read/following?number=20")
        case .p2s: posts = try await get("read/a8c?number=20")
        case .site(let id, let isFeed): posts = try await get(Self.streamPath(id, isFeed: isFeed, number: 20))
        case .saved: posts = saved
        }
        return Page(posts: posts, before: posts.last?.date, done: posts.isEmpty || feed == .saved)
    }

    private static func streamPath(_ id: Int, isFeed: Bool, number: Int) -> String {
        isFeed ? "read/feed/\(id)/posts?number=\(number)" : "read/sites/\(id)/posts?number=\(number)"
    }

    private func loadSubscriptions() async {
        struct Sub: Decodable {
            let blog_ID: String; let name: String?; let site_icon: String?; let is_wpforteams_site: Bool?
        }
        struct Response: Decodable { let subscriptions: [Sub] }
        guard let data = try? await store.request("read/following/mine?number=200", version: "v1.2"),
              let res = try? JSONDecoder().decode(Response.self, from: data) else { return }
        var map: [Int: ReaderSite] = [:]
        for s in res.subscriptions {
            guard let id = Int(s.blog_ID) else { continue }
            map[id] = ReaderSite(id: id, name: s.name ?? "", icon: s.site_icon, isP2: s.is_wpforteams_site ?? false)
        }
        sites = map
    }

    func siteName(_ id: Int) -> String {
        sites[id]?.name ?? visited[id]?.name
            ?? posts.first { $0.site_ID == id }?.site_name ?? "Site"
    }

    func icon(for post: ReaderPost) -> String? {
        if let img = post.site_icon?.img, !img.isEmpty { return img }
        return sites[post.site_ID]?.icon
    }

    func icon(forSite id: Int) -> String? { sites[id]?.icon ?? extraIcons[id] ?? visited[id]?.icon }

    /// Sites opened by name that we don't follow, so the site header has a name and icon right away.
    @Published private(set) var visited: [Int: ReaderSite] = [:]
    func remember(_ site: ReaderSite) { visited[site.id] = site }

    /// Fetches a site's icon once. Private P2s you can't access just keep the letter placeholder.
    func loadIcon(forSite id: Int) async {
        guard sites[id]?.icon == nil, extraIcons[id] == nil, !iconLookups.contains(id) else { return }
        iconLookups.insert(id)
        struct Site: Decodable { struct Icon: Decodable { let img: String? }; let icon: Icon? }
        guard let data = try? await store.request("sites/\(id)?fields=icon"),
              let img = (try? JSONDecoder().decode(Site.self, from: data))?.icon?.img else { return }
        extraIcons[id] = img
    }

    // MARK: Comments

    private var commentCache: [String: [PostComment]] = [:]

    /// Comments in thread order (each reply right after its parent), with depth for indenting.
    func comments(site: Int, post: Int) async -> [PostComment] {
        let key = "\(site)-\(post)"
        if let cached = commentCache[key] { return cached }
        struct Response: Decodable { let comments: [PostComment] }
        guard let data = try? await store.request(
                "sites/\(site)/posts/\(post)/replies?number=100&order=ASC&fields=ID,author,date,content,parent,like_count,i_like"),
              let flat = try? JSONDecoder().decode(Response.self, from: data).comments else { return [] }

        let children = Dictionary(grouping: flat.filter { $0.parentID != nil }, by: { $0.parentID! })
        let known = Set(flat.map(\.id))
        var ordered: [PostComment] = []
        func walk(_ c: PostComment, _ depth: Int) {
            var c = c
            c.depth = depth
            ordered.append(c)
            for child in children[c.id] ?? [] { walk(child, depth + 1) }
        }
        for root in flat where root.parentID.map({ !known.contains($0) }) ?? true { walk(root, 0) }
        commentCache[key] = ordered
        return ordered
    }

    func cachedComments(site: Int, post: Int) -> [PostComment]? { commentCache["\(site)-\(post)"] }

    /// The drawer edits its own copy of a thread (likes, new comments); this keeps the cache in step.
    func storeComments(_ comments: [PostComment], site: Int, post: Int) {
        commentCache["\(site)-\(post)"] = comments
    }

    /// Likes or unlikes a comment. Returns WordPress.com's count afterwards.
    func setLike(_ like: Bool, comment: Int, site: Int) async throws -> (iLike: Bool, count: Int) {
        struct Response: Decodable { let i_like: Bool; let like_count: Int }
        let path = "sites/\(site)/comments/\(comment)/likes/" + (like ? "new" : "mine/delete")
        let r = try JSONDecoder().decode(Response.self, from: try await store.request(path, method: "POST"))
        return (r.i_like, r.like_count)
    }

    /// Comments on the post, or replies to `parent`. Returns the new comment.
    func postComment(_ text: String, site: Int, post: Int, replyingTo parent: Int?) async throws -> PostComment {
        let path = parent.map { "sites/\(site)/comments/\($0)/replies/new" } ?? "sites/\(site)/posts/\(post)/replies/new"
        let body = try JSONEncoder().encode(["content": text])
        return try JSONDecoder().decode(PostComment.self, from: try await store.request(path, method: "POST", body: body))
    }

    // MARK: Likes
    // Real WordPress.com post likes. X-posts like the original post, not the snippet.

    struct LikeState { var liked: Bool; var count: Int }
    /// What we've learned since the feed loaded (toggles, x-post originals), keyed by "site-post".
    @Published private(set) var likes: [String: LikeState] = [:]

    private func likeTarget(_ post: ReaderPost) -> (site: Int, post: Int)? {
        if let origin = post.xpostOrigin { return origin }
        return post.isExternal ? nil : (post.site_ID, post.postID)
    }

    func canLike(_ post: ReaderPost) -> Bool { likeTarget(post) != nil }

    /// Nil while an x-post's original hasn't been looked up yet.
    func likeState(_ post: ReaderPost) -> LikeState? {
        guard let t = likeTarget(post) else { return nil }
        if let known = likes["\(t.site)-\(t.post)"] { return known }
        return post.isXPost ? nil : LikeState(liked: post.i_like ?? false, count: post.like_count ?? 0)
    }

    /// X-posts carry the snippet's likes, so fetch the original's.
    func loadLikeState(for post: ReaderPost) async {
        guard post.isXPost, let t = likeTarget(post), likes["\(t.site)-\(t.post)"] == nil else { return }
        struct Response: Decodable { let like_count: Int?; let i_like: Bool? }
        guard let data = try? await store.request("sites/\(t.site)/posts/\(t.post)?fields=like_count,i_like"),
              let r = try? JSONDecoder().decode(Response.self, from: data) else { return }
        likes["\(t.site)-\(t.post)"] = LikeState(liked: r.i_like ?? false, count: r.like_count ?? 0)
    }

    /// Flips the like right away, then settles on WordPress.com's answer (or flips back).
    func toggleLike(_ post: ReaderPost) async {
        guard let t = likeTarget(post), let before = likeState(post) else { return }
        let key = "\(t.site)-\(t.post)"
        let like = !before.liked
        likes[key] = LikeState(liked: like, count: max(0, before.count + (like ? 1 : -1)))
        struct Response: Decodable { let i_like: Bool; let like_count: Int }
        let path = "sites/\(t.site)/posts/\(t.post)/likes/" + (like ? "new" : "mine/delete")
        if let data = try? await store.request(path, method: "POST"),
           let r = try? JSONDecoder().decode(Response.self, from: data) {
            likes[key] = LikeState(liked: r.i_like, count: r.like_count)
        } else {
            likes[key] = before
        }
    }

    // MARK: Saves

    func isSaved(_ post: ReaderPost) -> Bool { saved.contains { $0.id == post.id } }

    func toggleSave(_ post: ReaderPost) {
        if let i = saved.firstIndex(where: { $0.id == post.id }) { saved.remove(at: i) } else { saved.insert(post, at: 0) }
        if feed == .saved { posts = saved }
        persist()
    }

    // MARK: Reader page

    func page(for post: ReaderPost) async -> String {
        if let cached = pages[post.id] { return cached }
        if post.isXPost {
            let html = await xpostPage(for: post)
            pages[post.id] = html
            return html
        }
        var content = post.content
        if content?.isEmpty ?? true, !post.isExternal,
           let data = try? await store.request("sites/\(post.site_ID)/posts/\(post.postID)?fields=content") {
            struct Full: Decodable { let content: String? }
            content = (try? JSONDecoder().decode(Full.self, from: data))?.content
        }
        let avatar = post.author?.avatar_URL.flatMap { $0.isEmpty ? nil : $0 } ?? icon(for: post)
        let html = ReaderPage.html(
            eyebrow: nil, title: post.title ?? "",
            author: post.author?.name, avatar: avatar, date: post.date, url: post.URL,
            likers: [], content: content ?? "", terms: store.mentionTerms,
            eyebrowHTML: ReaderPage.siteLink(post.site_ID, isFeed: post.isExternal,
                                             label: post.site_name ?? siteName(post.site_ID)))
        pages[post.id] = html
        return html
    }

    /// The original post behind an x-post, or the snippet plus a way out if that P2 is off limits.
    private func xpostPage(for post: ReaderPost) async -> String {
        struct Original: Decodable {
            let title: String?; let content: String?; let date: String?; let URL: String?; let author: ReaderPost.Author?
        }
        let source = post.xpostSource
        let from = post.xpostOrigin.map { ReaderPage.siteLink($0.site, label: source.handle) }
            ?? ReaderPage.escape(source.handle)
        let route = "Cross-posted \(from) → \(ReaderPage.siteLink(post.site_ID, label: post.destinationHandle))"

        if let origin = post.xpostOrigin,
           let data = try? await store.request("sites/\(origin.site)/posts/\(origin.post)?fields=title,content,date,URL,author"),
           let original = try? JSONDecoder().decode(Original.self, from: data), original.content != nil {
            return ReaderPage.html(
                eyebrow: nil, title: original.title ?? post.xpostTitle,
                author: original.author?.name, avatar: original.author?.avatar_URL, date: original.date,
                url: original.URL ?? post.originalURL, likers: [], content: original.content ?? "",
                terms: store.mentionTerms, eyebrowHTML: route)
        }

        let link = (post.originalURL ?? post.URL).map {
            " <a href=\"\(ReaderPage.escape($0))\">Open the original in your browser →</a>"
        } ?? ""
        let notice = "<div class=notice><strong>You don’t have access to \(ReaderPage.escape(source.handle)).</strong> "
            + "This is only the cross-post snippet.\(link)</div>"
        return ReaderPage.html(
            eyebrow: nil, title: ReaderPage.escape(post.xpostTitle),
            author: post.author?.name, avatar: post.author?.avatar_URL, date: post.date, url: post.originalURL ?? post.URL,
            likers: [], content: notice + (post.content ?? ""), terms: store.mentionTerms, eyebrowHTML: route)
    }

    func prefetch(_ post: ReaderPost) {
        // Comments too, so the drawer can swap straight to them on j.
        if let t = likeTarget(post), commentCache["\(t.site)-\(t.post)"] == nil {
            Task { _ = await comments(site: t.site, post: t.post) }
        }
        guard pages[post.id] == nil else { return }
        Task { _ = await page(for: post) }
    }

    // MARK: Persistence

    // Older builds also stored `starred` sites here; decoding ignores it.
    private struct File: Codable { var saved: [ReaderPost] = [] }

    private static let fileURL: URL = {
        AppData.directory.appendingPathComponent("reader.json")
    }()

    private static func loadFile() -> File {
        guard let data = try? Data(contentsOf: fileURL) else { return File() }
        return (try? JSONDecoder().decode(File.self, from: data)) ?? File()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(File(saved: saved)) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}
