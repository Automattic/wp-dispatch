import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var c: PanelController

    var body: some View {
        if !store.isConnected {
            SetupView().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            // Trailing-aligned and clipped: while the panel widens, the reader is
            // revealed from behind the list like a drawer sliding open. `minWidth: 0` keeps the
            // frame at the window's width; without it the frame grows to fit the wider HStack and
            // the window centers it, so the list jumps sideways before the reader appears.
            HStack(spacing: 0) {
                if c.showDetail {
                    DetailPane()
                        .frame(width: c.mode == .attached ? c.detailWidth : nil)
                        .frame(maxWidth: c.mode == .detached ? .infinity : nil)
                    Divider()
                }
                ListPane().frame(width: c.listWidth)
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .clipped()
            .overlay(alignment: .bottom) {
                if c.mode == .attached { HeightHandle() }
            }
            .ignoresSafeArea() // the detached window's hidden titlebar would otherwise leave a strip
        }
    }
}

// MARK: - List pane

struct ListPane: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var reader: ReaderStore
    @EnvironmentObject var c: PanelController

    private var loading: Bool { c.section == .notifications ? store.isLoading : reader.isLoading }

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: which app, plus window chrome.
            HStack(spacing: 4) {
                SectionTab("Notifications", badge: store.unreadCount, on: c.section == .notifications) {
                    c.switchSection(.notifications)
                }
                SectionTab("Reader", on: c.section == .reader) { c.switchSection(.reader) }
                    .padding(.leading, 10)
                Spacer()
                if loading { ProgressView().controlSize(.small).padding(.trailing, 2) }
                IconButton("arrow.clockwise", help: "Refresh") { Task { await c.refreshCurrent() } }
                if c.mode == .attached {
                    IconButton("macwindow.on.rectangle", help: "Pop out into a window (or drag the header)") { c.detach() }
                } else {
                    IconButton("menubar.arrow.up.rectangle", help: "Put back in the menu bar") { c.attach() }
                }
                Menu {
                    Button("Open on WordPress.com") {
                        NSWorkspace.shared.open(URL(string: c.section == .reader
                            ? "https://wordpress.com/reader" : "https://wordpress.com/notifications")!)
                    }
                    Divider()
                    Button("Sign out") { store.signOut() }
                    Button("Quit") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                if c.mode == .detached {
                    IconButton("xmark", help: "Close (⌘W)") { c.attach(show: false) }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .frame(height: 48)
            .background(WindowDragArea { c.dragWindow(with: $0) })

            // Row 2: filters for the current section.
            Group {
                if c.section == .notifications { NotificationFilters() } else { ReaderFilters() }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .padding(.bottom, 6)

            Divider().opacity(0.6)

            if c.section == .notifications { NotificationList() } else { PostList() }
        }
    }
}

struct SectionTab: View {
    let title: String
    var badge = 0
    let on: Bool
    let action: () -> Void

    init(_ title: String, badge: Int = 0, on: Bool, action: @escaping () -> Void) {
        self.title = title
        self.badge = badge
        self.on = on
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title).font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(on ? .primary : .tertiary)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor.opacity(on ? 1 : 0.6)))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct NotificationFilters: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var c: PanelController

    var body: some View {
        HStack {
            PillPicker(options: [.init("All", false), .init("Unread", true, badge: store.unreadCount)],
                       selection: c.unreadOnly) { c.unreadOnly = $0 }
            Spacer()
            IconButton("checkmark.circle", help: "Mark all as read") { Task { await store.markAllRead() } }
                .disabled(store.unreadCount == 0)
        }
    }
}

struct ReaderFilters: View {
    @EnvironmentObject var reader: ReaderStore

    var body: some View {
        if case .site(let id, _) = reader.feed {
            HStack(spacing: 8) {
                Button { reader.show(reader.previousFeed) } label: {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
                SiteIcon(url: reader.sites[id]?.icon ?? reader.posts.first.flatMap(reader.icon(for:)),
                         name: reader.siteName(id), size: 20)
                Text(reader.siteName(id)).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Spacer()
                StarButton(on: reader.isStarred(id)) {
                    if let post = reader.posts.first { reader.toggleStar(post) }
                }
            }
        } else {
            HStack {
                PillPicker(options: [
                    .init("Blogs", ReaderStore.Feed.blogs),
                    .init("P2s", .p2s),
                    .init("Starred", .starred, symbol: "star.fill"),
                    .init("Saved", .saved, badge: reader.saved.count, symbol: "bookmark.fill", quietBadge: true),
                ], selection: reader.feed) { reader.show($0) }
                Spacer()
            }
        }
    }
}

// MARK: - Lists

struct NotificationList: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var c: PanelController
    @Namespace private var selection

    var body: some View {
        let notes = c.visibleNotes
        if let error = store.error {
            Text(error).font(.caption).foregroundStyle(.red).padding(12)
        }
        if notes.isEmpty && !store.isLoading {
            EmptyState(symbol: c.unreadOnly ? "checkmark.circle" : "tray",
                       title: c.unreadOnly ? "All caught up" : "No notifications")
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(notes) { note in
                            NoteRow(note: note, selected: note.id == c.selectedID, selection: selection).id(note.id)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 6)
                    .padding(.bottom, c.mode == .attached ? 18 : 6)
                }
                .onChange(of: c.selectedID) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id) } }
                }
            }
        }
    }
}

struct PostList: View {
    @EnvironmentObject var reader: ReaderStore
    @EnvironmentObject var c: PanelController
    @Namespace private var selection

    var body: some View {
        if let error = reader.error {
            Text(error).font(.caption).foregroundStyle(.red).padding(12)
        }
        if reader.posts.isEmpty {
            if reader.isLoading || !reader.hasLoaded {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch reader.feed {
                case .saved: EmptyState(symbol: "bookmark", title: "Nothing saved yet",
                                        detail: "Press s while reading, or right-click a post")
                case .starred: EmptyState(symbol: "star", title: "No starred sites",
                                          detail: "Star a blog or P2 to collect its posts here")
                default: EmptyState(symbol: "newspaper", title: "No posts")
                }
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(reader.posts) { post in
                            Group {
                                if post.isXPost {
                                    XPostRow(post: post, selected: post.id == c.selectedPostID, selection: selection)
                                } else {
                                    PostRow(post: post, selected: post.id == c.selectedPostID, selection: selection)
                                }
                            }
                                .id(post.id)
                                .onAppear {
                                    if post == reader.posts.last { Task { await reader.loadMore() } }
                                }
                        }
                        if reader.isLoading {
                            ProgressView().controlSize(.small).padding(12)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 6)
                    .padding(.bottom, c.mode == .attached ? 18 : 6)
                }
                .onChange(of: c.selectedPostID) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id) } }
                }
                .onChange(of: reader.feed) { _, _ in
                    if let first = reader.posts.first { proxy.scrollTo(first.id, anchor: .top) }
                }
            }
        }
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    var detail: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 28, weight: .light)).padding(.bottom, 2)
            Text(title).font(.system(size: 13, weight: .medium))
            if let detail { Text(detail).font(.system(size: 11.5)).foregroundStyle(.tertiary) }
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Rows

/// Shared row chrome: hover wash, and a selection highlight that glides between rows.
struct SelectableRow<Content: View>: View {
    let selected: Bool
    let selection: Namespace.ID
    var unread = false
    var compact = false
    let action: () -> Void
    @ViewBuilder let content: Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, 12)
                .padding(.vertical, compact ? 7 : 10)
                .background {
                    ZStack {
                        if hovering && !selected {
                            RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05))
                        }
                        if selected {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.16))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1))
                                .matchedGeometryEffect(id: "selection", in: selection)
                        }
                    }
                }
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .offset(x: 3)
                        .opacity(unread ? 1 : 0)
                        .scaleEffect(unread ? 1 : 0.3)
                        .animation(.spring(response: 0.3), value: unread)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }
}

struct NoteRow: View {
    @EnvironmentObject var c: PanelController
    let note: Note
    let selected: Bool
    let selection: Namespace.ID

    var body: some View {
        SelectableRow(selected: selected, selection: selection, unread: note.isUnread, action: { c.select(note) }) {
            HStack(alignment: .top, spacing: 11) {
                Avatar(url: note.icon, kind: note.kind)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        (Text(note.actor ?? "").fontWeight(.semibold)
                         + Text(note.actor == nil ? note.action : " " + note.action).foregroundStyle(.secondary))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(note.date.map(shortTime) ?? "")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(note.isUnread ? Color.accentColor : .secondary)
                    }
                    .font(.system(size: 12))

                    if let target = note.target {
                        Text(target.plainText)
                            .font(.system(size: 13, weight: note.isUnread ? .semibold : .medium))
                            .lineLimit(2)
                    }
                    if let excerpt = note.excerpt, !excerpt.isEmpty {
                        Text(excerpt).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            }
        }
    }
}

struct PostRow: View {
    @EnvironmentObject var reader: ReaderStore
    @EnvironmentObject var c: PanelController
    let post: ReaderPost
    let selected: Bool
    let selection: Namespace.ID

    var body: some View {
        let site = post.site_name ?? reader.siteName(post.site_ID)
        SelectableRow(selected: selected, selection: selection, action: { c.select(post) }) {
            HStack(alignment: .top, spacing: 11) {
                SiteIcon(url: reader.icon(for: post), name: site, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(site.plainText).fontWeight(.semibold).foregroundStyle(.secondary).lineLimit(1)
                        if reader.isStarred(post.site_ID) {
                            Image(systemName: "star.fill").font(.system(size: 8.5)).foregroundStyle(.yellow)
                        }
                        Spacer(minLength: 4)
                        Text(post.dateValue.map(shortTime) ?? "")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12))

                    Text((post.title ?? "").plainText.isEmpty ? "Untitled" : (post.title ?? "").plainText)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    let excerpt = (post.excerpt ?? "").plainText
                    if !excerpt.isEmpty {
                        Text(excerpt).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    HStack(spacing: 6) {
                        if let name = post.author?.name, !name.isEmpty, name != site {
                            Text(name)
                        }
                        if let time = post.readingTime { Text(time) }
                        if reader.isSaved(post) {
                            Image(systemName: "bookmark.fill").foregroundStyle(Color.accentColor)
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            }
        }
        .contextMenu {
            Button(reader.isSaved(post) ? "Remove from Saved" : "Save Post") { reader.toggleSave(post) }
            Button(reader.isStarred(post.site_ID) ? "Unstar \(site)" : "Star \(site)") { reader.toggleStar(post) }
            Button("Show Only \(site)") { reader.show(.site(post.site_ID, isFeed: post.isExternal)) }
            Divider()
            Button("Open in Browser") {
                if let s = post.URL, let url = URL(string: s) { NSWorkspace.shared.open(url) }
            }
        }
    }
}

/// Cross-posts are pointers to a post on another P2, so they get a slim row:
/// where it came from → where it landed, and the title.
struct XPostRow: View {
    @EnvironmentObject var reader: ReaderStore
    @EnvironmentObject var c: PanelController
    let post: ReaderPost
    let selected: Bool
    let selection: Namespace.ID

    var body: some View {
        let source = post.xpostSource
        SelectableRow(selected: selected, selection: selection, compact: true, action: { c.select(post) }) {
            HStack(alignment: .top, spacing: 11) {
                // Where it came from, badged as a cross-post (like the notification type badges).
                SiteIcon(url: post.xpostOrigin.flatMap { reader.icon(forSite: $0.site) },
                         name: source.handle.replacingOccurrences(of: "+", with: ""), size: 26)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 6.5, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 13, height: 13)
                            .background(Color.gray.gradient, in: Circle())
                            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                            .offset(x: 4, y: 4)
                    }
                    .frame(width: 34)
                    .task { if let origin = post.xpostOrigin { await reader.loadIcon(forSite: origin.site) } }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(source.handle).fontWeight(.semibold)
                        Image(systemName: "arrow.right").font(.system(size: 8, weight: .bold)).foregroundStyle(.tertiary)
                        Text(post.destinationHandle)
                        if reader.isSaved(post) {
                            Image(systemName: "bookmark.fill").font(.system(size: 9)).foregroundStyle(Color.accentColor)
                        }
                        Spacer(minLength: 4)
                        Text(post.dateValue.map(shortTime) ?? "").monospacedDigit()
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    Text(post.xpostTitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            }
        }
        .help("Cross-posted from \(source.name ?? source.handle) to \(post.site_name ?? post.destinationHandle)")
        .contextMenu {
            Button(reader.isSaved(post) ? "Remove from Saved" : "Save Post") { reader.toggleSave(post) }
            Divider()
            Button("Open Original in Browser") {
                if let s = post.originalURL ?? post.URL, let url = URL(string: s) { NSWorkspace.shared.open(url) }
            }
        }
    }
}

private func shortTime(_ date: Date) -> String {
    let s = Date.now.timeIntervalSince(date)
    switch s {
    case ..<60: return "now"
    case ..<3600: return "\(Int(s / 60))m"
    case ..<86_400: return "\(Int(s / 3600))h"
    case ..<604_800: return "\(Int(s / 86_400))d"
    default: return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

/// People are circles; sites are rounded squares.
struct SiteIcon: View {
    let url: String?
    let name: String
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url.flatMap(URL.init(string:))) { img in
            img.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                LinearGradient(colors: [hue.opacity(0.85), hue], startPoint: .top, endPoint: .bottom)
                Text(String(name.plainText.prefix(1)).uppercased())
                    .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private var hue: Color {
        let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .green]
        // Stable across launches (String.hashValue is randomized per process).
        return palette[name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palette.count]
    }
}

struct Avatar: View {
    let url: String?
    let kind: Note.Kind

    var body: some View {
        AsyncImage(url: url.flatMap(URL.init(string:))) { img in
            img.resizable().scaledToFill()
        } placeholder: {
            Color.secondary.opacity(0.15)
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: glyph.symbol)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 15, height: 15)
                .background(glyph.color.gradient, in: Circle())
                .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                .offset(x: 3, y: 3)
        }
    }

    private var glyph: (symbol: String, color: Color) {
        switch kind {
        case .mention: return ("at", .orange)
        case .comment: return ("bubble.left.fill", .blue)
        case .like: return ("star.fill", .pink)
        case .follow: return ("person.fill", .green)
        case .other: return ("bell.fill", .gray)
        }
    }
}

// MARK: - Reader pane

struct DetailPane: View {
    @EnvironmentObject var reader: ReaderStore
    @EnvironmentObject var c: PanelController

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if c.mode == .attached {
                    IconButton("xmark", help: "Close reader (esc)") { c.closeDetail() }
                }
                if c.section == .reader, let post = c.selectedPost {
                    StarButton(on: reader.isStarred(post.site_ID)) { reader.toggleStar(post) }
                        .help(reader.isStarred(post.site_ID) ? "Unstar this site" : "Star this site")
                    IconButton(reader.isSaved(post) ? "bookmark.fill" : "bookmark",
                               help: reader.isSaved(post) ? "Remove from Saved (s)" : "Save post (s)",
                               tint: reader.isSaved(post) ? .accentColor : nil) { reader.toggleSave(post) }
                }
                IconButton("safari", help: "Open in browser (o)") { c.openSelectedInBrowser() }
                    .disabled(c.selectedNote == nil && c.selectedPost == nil)
                Spacer()
                // Prev/next sit on the right, next to the list they step through.
                if let p = c.position {
                    Text("\(p.index + 1) of \(p.count)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                }
                IconButton("chevron.up", help: "Previous (k)") { c.move(-1) }
                    .disabled((c.position?.index ?? 0) == 0)
                IconButton("chevron.down", help: "Next (j)") { c.move(1) }
                    .disabled(c.position.map { $0.index == $0.count - 1 } ?? true)
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(WindowDragArea { c.dragWindow(with: $0) })

            Divider().opacity(0.6)

            Group {
                if c.section == .notifications, let note = c.selectedNote {
                    WebContent(id: "n\(note.id)", baseURL: note.url) { await c.store.page(for: note) }
                } else if c.section == .reader, let post = c.selectedPost {
                    WebContent(id: post.id, baseURL: post.URL) { await reader.page(for: post) }
                } else {
                    ReaderPlaceholder(reader: c.section == .reader)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let t = c.commentTarget {
                CommentsDrawer(site: t.site, post: t.post).id("\(t.site)-\(t.post)")
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
    }
}

// MARK: - Comments

/// Closed: a row of avatars with chat-bubble snippets. Open: the same avatars and
/// bubbles spring into a threaded list that scrolls separately from the post.
struct CommentsDrawer: View {
    @EnvironmentObject var reader: ReaderStore
    @EnvironmentObject var c: PanelController
    let site: Int
    let post: Int
    @State private var comments: [PostComment]?
    @State private var appeared = false
    @State private var focus: Int?
    @Namespace private var ns

    private let spring = Animation.spring(response: 0.48, dampingFraction: 0.8)

    var body: some View {
        // A real (zero-height) view so `.task` runs before there's anything to show.
        VStack(spacing: 0) {
            Color.clear.frame(height: 0)
            if let comments, !comments.isEmpty {
                VStack(spacing: 0) {
                    Divider().opacity(0.6)
                    header(comments.count)
                    if c.commentsOpen { list(comments) } else { strip(comments) }
                }
                .background(Color.primary.opacity(0.025))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            let loaded = await reader.comments(site: site, post: post)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { comments = loaded }
            try? await Task.sleep(for: .milliseconds(60))
            appeared = true
        }
    }

    private func toggle(focusing id: Int? = nil) {
        focus = id
        withAnimation(spring) { c.commentsOpen.toggle() }
    }

    private func header(_ count: Int) -> some View {
        Button { toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                Text(count == 1 ? "1 comment" : "\(count) comments")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(c.commentsOpen ? 180 : 0))
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(c.commentsOpen ? "Hide comments" : "Show comments")
    }

    private func strip(_ comments: [PostComment]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(comments.enumerated()), id: \.element.id) { i, comment in
                    Button { toggle(focusing: comment.id) } label: {
                        CommentBubble(comment: comment, expanded: false, ns: ns)
                    }
                    .buttonStyle(.plain)
                    .help(comment.author?.name ?? "")
                    // Bubbles pop in one after another.
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .scaleEffect(appeared ? 1 : 0.85, anchor: .bottomLeading)
                    .animation(.spring(response: 0.42, dampingFraction: 0.68).delay(Double(min(i, 14)) * 0.045),
                               value: appeared)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 14)
            .background(WheelScrollsSideways())
        }
    }

    private func list(_ comments: [PostComment]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(comments) { comment in
                        CommentBubble(comment: comment, expanded: true, ns: ns)
                            .padding(.leading, CGFloat(min(comment.depth, 3)) * 24)
                            .id(comment.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .frame(maxHeight: .infinity)
            .onAppear {
                if let focus { DispatchQueue.main.async { withAnimation(spring) { proxy.scrollTo(focus, anchor: .top) } } }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 160, idealHeight: 280, maxHeight: .infinity)
        .layoutPriority(1)
    }
}

/// One comment: avatar plus a speech bubble. Shares geometry IDs between the
/// strip and the list so toggling morphs one into the other.
struct CommentBubble: View {
    let comment: PostComment
    let expanded: Bool
    let ns: Namespace.ID

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            AsyncImage(url: comment.author?.avatar_URL.flatMap(URL.init(string:))) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .matchedGeometryEffect(id: "avatar\(comment.id)", in: ns)

            VStack(alignment: .leading, spacing: 3) {
                if expanded {
                    HStack(spacing: 6) {
                        Text(comment.author?.name ?? "Someone").font(.system(size: 12, weight: .semibold))
                        if let date = comment.dateValue {
                            Text(date, style: .relative).font(.system(size: 11)).foregroundStyle(.tertiary)
                        }
                    }
                }
                Text(expanded ? comment.text : comment.snippet)
                    .font(.system(size: expanded ? 12.5 : 12))
                    .lineLimit(expanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(width: expanded ? nil : 190, alignment: .leading)
            .frame(maxWidth: expanded ? .infinity : nil, alignment: .leading)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 14,
                                       bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                    .matchedGeometryEffect(id: "bubble\(comment.id)", in: ns)
            )
        }
        .padding(.top, 2)
    }
}

struct WebContent: View {
    let id: String
    let baseURL: String?
    let load: () async -> String

    var body: some View {
        Loaded(baseURL: baseURL, load: load).id(id)
    }

    private struct Loaded: View {
        let baseURL: String?
        let load: () async -> String
        @State private var html: String?

        var body: some View {
            ZStack {
                if let html {
                    HTMLView(html: html, baseURL: baseURL.flatMap(URL.init(string:))).transition(.opacity)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .animation(.easeOut(duration: 0.18), value: html != nil)
            .task { html = await load() }
        }
    }
}

struct ReaderPlaceholder: View {
    let reader: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: WordPressLogo.image)
                .resizable()
                .frame(width: 40, height: 40)
                .opacity(0.18)
            Text("Pick something to read").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            Text(reader ? "↑ ↓ or j k to move · s to save · o to open" : "↑ ↓ or j k to move · o to open in browser")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Chrome

struct PillPicker<T: Hashable>: View {
    struct Option {
        let title: String
        let value: T
        var badge = 0
        var symbol: String?
        /// Gray count instead of the blue "unread" badge.
        var quietBadge = false

        init(_ title: String, _ value: T, badge: Int = 0, symbol: String? = nil, quietBadge: Bool = false) {
            self.title = title
            self.value = value
            self.badge = badge
            self.symbol = symbol
            self.quietBadge = quietBadge
        }
    }

    let options: [Option]
    let selection: T?
    let onSelect: (T) -> Void
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in segment(options[i]) }
        }
        .padding(2)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
    }

    private func segment(_ o: Option) -> some View {
        let on = selection == o.value
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { onSelect(o.value) }
        } label: {
            HStack(spacing: 4) {
                if let symbol = o.symbol {
                    Image(systemName: symbol).font(.system(size: 9.5))
                        .foregroundStyle(on ? (symbol.hasPrefix("star") ? Color.yellow : .accentColor) : .secondary)
                }
                Text(o.title)
                if o.badge > 0 {
                    Text("\(o.badge)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(o.quietBadge ? Color.secondary : .white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(o.quietBadge ? Color.primary.opacity(0.08) : .accentColor))
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(on ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                if on {
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.12), radius: 1.5, y: 0.5)
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct StarButton: View {
    let on: Bool
    let action: () -> Void

    var body: some View {
        IconButton(on ? "star.fill" : "star", help: on ? "Unstar site" : "Star site",
                   tint: on ? .yellow : nil, action: action)
    }
}

/// Drag the bottom edge of the attached panel to set its height.
struct HeightHandle: View {
    @EnvironmentObject var c: PanelController
    @State private var hovering = false
    @State private var dragging = false

    var body: some View {
        ZStack {
            ResizeArea(
                onHover: { hovering = $0 },
                onBegin: { dragging = true; c.beginResize() },
                onChange: { c.updateResize() },
                onEnd: { dragging = false; c.endResize() })
            Capsule()
                .fill(Color.primary.opacity(hovering || dragging ? 0.4 : 0.14))
                .frame(width: dragging ? 48 : 36, height: 4)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 14)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.spring(response: 0.25), value: dragging)
    }
}

/// AppKit owns the cursor here: SwiftUI's push/pop gets out of balance and the
/// hosting view resets it, so the resize cursor only showed up some of the time.
struct ResizeArea: NSViewRepresentable {
    let onHover: (Bool) -> Void
    let onBegin: () -> Void
    let onChange: () -> Void
    let onEnd: () -> Void

    func makeNSView(context: Context) -> ResizeView { ResizeView() }

    func updateNSView(_ view: ResizeView, context: Context) {
        view.onHover = onHover
        view.onBegin = onBegin
        view.onChange = onChange
        view.onEnd = onEnd
    }

    final class ResizeView: NSView {
        var onHover: (Bool) -> Void = { _ in }
        var onBegin: () -> Void = {}
        var onChange: () -> Void = {}
        var onEnd: () -> Void = {}
        private var area: NSTrackingArea?
        private var dragging = false

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let area { removeTrackingArea(area) }
            let a = NSTrackingArea(rect: .zero,
                                   options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect],
                                   owner: self)
            addTrackingArea(a)
            area = a
        }

        override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeUpDown) }
        override func cursorUpdate(with event: NSEvent) { NSCursor.resizeUpDown.set() }
        override func mouseEntered(with event: NSEvent) { onHover(true); NSCursor.resizeUpDown.set() }
        override func mouseMoved(with event: NSEvent) { NSCursor.resizeUpDown.set() }
        override func mouseExited(with event: NSEvent) {
            onHover(false)
            if !dragging { NSCursor.arrow.set() }
        }

        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            dragging = true
            NSCursor.resizeUpDown.set()
            onBegin()
        }

        override func mouseDragged(with event: NSEvent) {
            NSCursor.resizeUpDown.set()
            onChange()
        }

        override func mouseUp(with event: NSEvent) {
            dragging = false
            onEnd()
            let inside = bounds.contains(convert(event.locationInWindow, from: nil))
            onHover(inside)
            if !inside { NSCursor.arrow.set() }
        }
    }
}

/// A horizontal ScrollView ignores a mouse's (vertical) wheel. Placed inside one, this
/// turns vertical wheel/swipe movement over it into sideways scrolling.
struct WheelScrollsSideways: NSViewRepresentable {
    func makeNSView(context: Context) -> WheelView { WheelView() }
    func updateNSView(_ view: WheelView, context: Context) {}

    final class WheelView: NSView {
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.redirect(event) ?? event
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil } // never steal clicks

        private func redirect(_ event: NSEvent) -> NSEvent? {
            guard event.window === window, let scroll = enclosingScrollView,
                  abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) else { return event }
            let point = scroll.convert(event.locationInWindow, from: nil)
            guard scroll.bounds.contains(point) else { return event }

            // Wheel deltas are in lines; trackpad deltas are already points.
            let delta = event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 14)
            let clip = scroll.contentView
            let maxX = max(0, (scroll.documentView?.frame.width ?? 0) - clip.bounds.width)
            clip.scroll(to: NSPoint(x: min(max(clip.bounds.origin.x - delta, 0), maxX), y: clip.bounds.origin.y))
            scroll.reflectScrolledClipView(clip)
            return nil
        }

        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}

/// Empty header space that drags the window (and tears the panel off the menu bar).
struct WindowDragArea: NSViewRepresentable {
    let onDrag: (NSEvent) -> Void

    func makeNSView(context: Context) -> DragView { DragView(onDrag: onDrag) }
    func updateNSView(_ view: DragView, context: Context) { view.onDrag = onDrag }

    final class DragView: NSView {
        var onDrag: (NSEvent) -> Void
        init(onDrag: @escaping (NSEvent) -> Void) { self.onDrag = onDrag; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { onDrag(event) }
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    var tint: Color?
    let action: () -> Void
    @State private var hovering = false

    init(_ symbol: String, help: String, tint: Color? = nil, action: @escaping () -> Void) {
        self.symbol = symbol
        self.help = help
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(tint ?? .secondary)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { h in withAnimation(.easeOut(duration: 0.1)) { hovering = h } }
    }
}

extension String {
    /// Like `plainText`, but keeps paragraph and line breaks (for comments).
    var commentText: String {
        let marked = replacingOccurrences(of: #"(?i)<br\s*/?>|</p>|</li>|</blockquote>"#, with: "¶¶",
                                          options: .regularExpression)
        return marked.plainText
            .replacingOccurrences(of: #"\s*¶¶\s*"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n{2,}"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cheap HTML → text for list rows: strips tags and decodes common entities.
    /// (NSAttributedString's HTML importer is far too slow to run per row.)
    var plainText: String {
        guard contains("<") || contains("&") else { return self }
        var s = replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let named = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&nbsp;": " ",
                     "&hellip;": "…", "&ndash;": "–", "&mdash;": "—", "&rsquo;": "’", "&lsquo;": "‘",
                     "&rdquo;": "”", "&ldquo;": "“"]
        for (k, v) in named { s = s.replacingOccurrences(of: k, with: v) }
        while let r = s.range(of: "&#(x?)([0-9a-fA-F]+);", options: .regularExpression) {
            let body = s[r].dropFirst(2).dropLast()
            let value = body.hasPrefix("x") ? UInt32(body.dropFirst(), radix: 16) : UInt32(body)
            s.replaceSubrange(r, with: value.flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? "")
        }
        return s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Setup

struct SetupView: View {
    @EnvironmentObject var store: Store
    @State private var connecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(nsImage: WordPressLogo.image).resizable().frame(width: 28, height: 28).opacity(0.85)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.sessionExpired ? "Session expired" : "Connect WordPress.com").font(.headline)
                    Text(store.sessionExpired
                         ? "WordPress.com sign-ins last about two weeks. Reconnect to pick up where you left off."
                         : "Approve access in your browser. No passwords or secrets are stored here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let error = store.error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Quit") { NSApp.terminate(nil) }
                Spacer()
                Button(connecting ? "Waiting for browser…" : (store.sessionExpired ? "Reconnect" : "Connect")) {
                    connecting = true
                    Task { await store.connect(); connecting = false }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(connecting)
            }
        }
        .padding(18)
    }
}
