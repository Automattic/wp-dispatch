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
                        .driftTag("detail")
                        .frame(width: c.mode == .attached ? c.detailWidth : nil)
                        .frame(maxWidth: c.mode == .detached ? .infinity : nil)
                    Divider()
                }
                ListPane().driftTag("list").frame(width: c.listWidth)
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .clipped()
            .overlay(alignment: .bottom) {
                if c.mode == .attached { HeightHandle() }
            }
            .overlay {
                if c.showingKeys { KeyboardHelp().transition(.opacity.combined(with: .scale(scale: 0.97))) }
            }
            .animation(.easeOut(duration: 0.15), value: c.showingKeys)
            .ignoresSafeArea() // the detached window's hidden titlebar would otherwise leave a strip
        }
    }
}

// MARK: - List pane

struct ListPane: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var reader: ReaderStore
    @EnvironmentObject var c: PanelController

    private var loading: Bool {
        switch c.section {
        case .notifications: store.isLoading
        case .reader: reader.isLoading
        case .later: false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row 1: which app, plus window chrome.
            HStack(spacing: 4) {
                SectionTab("Notifications", badge: store.unreadCount, on: c.section == .notifications) {
                    c.switchSection(.notifications)
                }
                .driftTag("tab.notifications")
                SectionTab("Reader", on: c.section == .reader) { c.switchSection(.reader) }
                    .driftTag("tab.reader")
                    .padding(.leading, 10)
                LaterTab()
                    .driftTag("tab.later")
                    .padding(.leading, 10)
                Spacer()
                if loading { ProgressView().controlSize(.small).padding(.trailing, 2) }
                IconButton("arrow.clockwise", help: "Refresh") { Task { await c.refreshCurrent() } }.driftTag("btn.refresh")
                if c.mode == .attached {
                    IconButton("macwindow.on.rectangle", help: "Pop out into a window (or drag the header)") { c.detach() }
                        .driftTag("btn.popout")
                } else {
                    IconButton("menubar.arrow.up.rectangle", help: "Put back in the menu bar") { c.attach() }
                }
                MoreMenu().driftTag("btn.more")
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
                switch c.section {
                case .notifications: NotificationFilters()
                case .reader: ReaderFilters()
                case .later: LaterFilters()
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .padding(.bottom, 6)

            Divider().opacity(0.6)

            switch c.section {
            case .notifications: NotificationList()
            case .reader: PostList()
            case .later: LaterList()
            }
        }
    }
}

/// The ⋯ menu. Sized and highlighted like an `IconButton`: a borderless `Menu` hugs its glyph,
/// so its hover wash was a squashed 20×14 pill.
struct MoreMenu: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var c: PanelController
    @State private var hovering = false

    var body: some View {
        Menu {
            Button("Open on WordPress.com") {
                NSWorkspace.shared.open(URL(string: c.section == .reader
                    ? "https://wordpress.com/reader" : "https://wordpress.com/notifications")!)
            }
            Divider()
            Toggle("Show in Dock", isOn: $c.showInDock)
            Toggle("Open as a Window", isOn: $c.opensAsWindow)
            Picker("Menu Bar Count", selection: $c.menuBarCount) {
                ForEach(PanelController.MenuBarCount.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Menu("Notify Me About") {
                ForEach(Alerts.Kind.allCases, id: \.self) { kind in
                    Toggle(kind.title, isOn: Binding(get: { Alerts.shared.isOn(kind) }, set: { Alerts.shared.set(kind, $0) }))
                }
            }
            Divider()
            Button("Keyboard Shortcuts") { c.showingKeys = true }
            Button("Check for Updates…") { Updates.shared.checkForUpdates() }
            Text("Dispatch \(Updates.shared.versionLabel)")
            Divider()
            Button("Sign out") { store.signOut() }
            Button("Restart") { Updates.relaunch() }
            Button("Quit") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
        .onHover { h in withAnimation(.easeOut(duration: 0.1)) { hovering = h } }
    }
}

// MARK: - Keyboard shortcuts

/// `?`: every shortcut, over the panel. Keep it in step with `PanelController.handleKey`.
struct KeyboardHelp: View {
    @EnvironmentObject var c: PanelController

    private let groups: [(String, [(keys: [String], what: String)])] = [
        ("Lists", [
            (["←", "→"], "Previous or next list, across sections"),
            (["⇧←", "⇧→"], "Previous or next section"),
            (["⌘1", "⌘2", "⌘3"], "Notifications, Reader, Later"),
            (["⇥", "⇧⇥"], "Next or previous section"),
            (["↑", "↓"], "Move through the list (or j, k)"),
            (["⌘↑"], "Back to the top"),
            (["esc"], "Back out: a site’s feed, the reader, the panel"),
        ]),
        ("Reading", [
            (["Space", "⇧Space"], "Page down or up"),
            (["l"], "Like"), (["s"], "Save"), (["m"], "Remind me later"), (["o"], "Open in the browser"),
            (["u"], "Mark a notification unread"), (["⌘+", "⌘−"], "Bigger or smaller text (⌘0 resets)"),
            (["click"], "An image, to see it full size"),
            (["c"], "Comments"), (["f"], "Comments full height"), (["r"], "Reply"), (["⌘↩"], "Send a comment"),
        ]),
        ("Later", [
            (["↑", "↓"], "Highlight a reminder"), (["↩"], "Open it"), (["⌫"], "Done"),
        ]),
    ]

    @ViewBuilder private var columns: some View {
        ForEach(groups, id: \.0) { title, rows in
            VStack(alignment: .leading, spacing: 7) {
                Text(title.uppercased()).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(rows, id: \.what) { row in
                    HStack(spacing: 8) {
                        HStack(spacing: 3) { ForEach(row.keys, id: \.self) { Keycap($0) } }
                            .frame(minWidth: 76, alignment: .leading)
                        Text(row.what).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.18).onTapGesture { c.showingKeys = false }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Keyboard Shortcuts").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    IconButton("xmark", help: "Close (esc)") { c.showingKeys = false }
                }
                // Side by side when the reader is open; one scrolling column when it's just the list.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 28) { columns }.fixedSize()
                    ScrollView { VStack(alignment: .leading, spacing: 16) { columns } }
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 8))
            .fixedSize(horizontal: false, vertical: false)
            .padding(16)
        }
    }
}

struct Keycap: View {
    let key: String
    init(_ key: String) { self.key = key }

    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.12)))
    }
}

// MARK: - Later

/// The Later tab. Its badge counts reminders that are due.
struct LaterTab: View {
    @EnvironmentObject var c: PanelController
    @ObservedObject private var reminders = Reminders.shared

    var body: some View {
        // Due ones re-count each minute.
        TimelineView(.everyMinute) { context in
            SectionTab("Later", badge: reminders.all.filter { $0.due <= context.date }.count, on: c.section == .later) {
                c.switchSection(.later)
            }
        }
    }
}

struct LaterFilters: View {
    @ObservedObject private var reminders = Reminders.shared

    var body: some View {
        HStack {
            Text(reminders.all.isEmpty ? "No reminders" : reminders.all.count == 1 ? "1 reminder, soonest first" : "\(reminders.all.count) reminders, soonest first")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            Spacer()
        }
    }
}

/// Every reminder, notifications and posts together, soonest first. Clicking opens the item where
/// it lives; it stays here until you mark it done.
struct LaterList: View {
    @EnvironmentObject var c: PanelController
    @ObservedObject private var reminders = Reminders.shared
    @Namespace private var selection

    var body: some View {
        if reminders.all.isEmpty {
            EmptyState(symbol: "alarm", title: "Nothing for later",
                       detail: "Use the alarm in the reader, or right-click any notification or post, to be reminded about it.")
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ListTop()
                    LazyVStack(spacing: 2) {
                        ForEach(Array(reminders.all.enumerated()), id: \.element.id) { i, r in
                            LaterRow(reminder: r, selection: selection).driftScope("row.\(i)")
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 6)
                    .padding(.bottom, c.mode == .attached ? 18 : 6)
                }
            }
        }
    }
}

struct LaterRow: View {
    @EnvironmentObject var c: PanelController
    @EnvironmentObject var reader: ReaderStore
    let reminder: Reminder
    let selection: Namespace.ID

    var body: some View {
        let note = reminder.noteID.flatMap { id in c.store.notes.first { $0.id == id } }
        SelectableRow(selected: c.laterHighlight == reminder.id, selection: selection, action: { c.open(reminder, clear: false) }) {
            HStack(alignment: .top, spacing: 11) {
                Group {
                    if let note {
                        Avatar(url: note.icon, kind: note.kind)
                    } else if let post = reminder.post {
                        SiteIcon(url: reader.icon(for: post), name: post.site_name ?? reader.siteName(post.site_ID), size: 34)
                    } else {
                        Image(systemName: "alarm").font(.system(size: 15)).foregroundStyle(.secondary)
                            .frame(width: 34, height: 34).background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                }
                .driftTag("icon")

                VStack(alignment: .leading, spacing: 2) {
                    TimelineView(.everyMinute) { context in
                        let due = reminder.due <= context.date
                        HStack(spacing: 4) {
                            Image(systemName: "alarm.fill").font(.system(size: 9.5))
                            Text(due ? "Due · \(Reminders.describe(reminder.due))" : Reminders.describe(reminder.due))
                        }
                        .font(.system(size: 11, weight: due ? .semibold : .medium))
                        .foregroundStyle(due ? Color.accentColor : .secondary)
                    }
                    .driftTag("when")
                    Text(reminder.title).font(.system(size: 13, weight: .semibold)).lineLimit(2).driftTag("title")
                    if let subtitle = reminder.subtitle {
                        Text(subtitle.plainText).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2).driftTag("excerpt")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

                IconButton("checkmark.circle", help: "Done") { Reminders.shared.cancel(reminder.id) }
                    .driftTag("done")
            }
        }
        .contextMenu {
            Button("Open") { c.open(reminder, clear: false) }
            RemindItems(id: reminder.id) { Reminders.shared.snooze(reminder.id, until: $0) }
            Divider()
            Button("Done") { Reminders.shared.cancel(reminder.id) }
        }
    }
}

/// "Remind Me" in the reader's toolbar: pick a time, or see and cancel the one that's set.
struct RemindMenu: View {
    let id: String
    let remind: (Date) -> Void
    @ObservedObject private var reminders = Reminders.shared
    @State private var hovering = false

    var body: some View {
        let set = reminders.reminder(id)
        Menu {
            if let set { Text("Reminding you \(Reminders.describe(set.due))") }
            RemindItems(id: id, remind: remind, flat: true)
        } label: {
            Image(systemName: set == nil ? "alarm" : "alarm.fill")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(set == nil ? Color.secondary : Color.accentColor)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(set.map { "Reminder: \(Reminders.describe($0.due))" } ?? "Remind me about this later")
        .onHover { h in withAnimation(.easeOut(duration: 0.1)) { hovering = h } }
        .driftTag("detail.remind")
    }
}

/// The reminder times, as menu items: under a "Remind Me" submenu, or `flat` in a menu of their own.
struct RemindItems: View {
    let id: String
    let remind: (Date) -> Void
    var flat = false
    @ObservedObject private var reminders = Reminders.shared

    var body: some View {
        if flat { items } else { Menu("Remind Me") { items } }
    }

    @ViewBuilder private var items: some View {
        ForEach(Reminders.choices()) { choice in
            Button("\(choice.title) — \(Reminders.describe(choice.due))") { remind(choice.due) }
        }
        if reminders.reminder(id) != nil {
            Divider()
            Button("Cancel Reminder") { reminders.cancel(id) }
        }
    }
}

/// A small clock beside a row's time while it has a reminder.
struct ReminderClock: View {
    let id: String
    @ObservedObject private var reminders = Reminders.shared

    var body: some View {
        if let r = reminders.reminder(id) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.accentColor)
                .help("Reminder: \(Reminders.describe(r.due))")
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
                        .driftTag("badge.\(title.lowercased())")
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
            BackToTopButton()
            IconButton("checkmark.circle", help: "Mark all as read") { Task { await store.markAllRead() } }
                .driftTag("btn.markall")
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
                BackToTopButton()
            }
        } else {
            HStack {
                PillPicker(options: [
                    .init("Following", ReaderStore.Feed.blogs),
                    .init("Automattic", .p2s),
                    .init("Saved", .saved, badge: reader.savedCount, symbol: "bookmark.fill", quietBadge: true),
                ], selection: reader.feed) { reader.show($0) }
                Spacer()
                BackToTopButton()
            }
        }
    }
}

/// Shows once the list has scrolled away from the top. ⌘↑ does the same.
struct BackToTopButton: View {
    @EnvironmentObject var c: PanelController

    var body: some View {
        if c.listScrolled {
            IconButton("arrow.up", help: "Back to top (⌘↑)") { c.scrollToTop() }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }
}

/// Zero-height view at the top of a list's scroll content: the target for back-to-top,
/// and it tells the controller whether the list has scrolled away from the top.
struct ListTop: View {
    static let id = "list-top"
    @EnvironmentObject var c: PanelController

    var body: some View {
        Color.clear.frame(height: 0).id(Self.id)
            .onGeometryChange(for: Bool.self) { $0.frame(in: .scrollView).minY < -60 } action: { scrolled in
                withAnimation(.easeOut(duration: 0.15)) { c.listScrolled = scrolled }
            }
            .onDisappear { c.listScrolled = false }
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
                    // ScrollView stacks with default spacing; keep the marker flush with the list.
                    VStack(spacing: 0) {
                        ListTop()
                        LazyVStack(spacing: 2) {
                            ForEach(Array(notes.enumerated()), id: \.element.id) { i, note in
                                NoteRow(note: note, selected: note.id == c.selectedID, selection: selection).id(note.id)
                                    .driftScope("row.\(i)")
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                        .padding(.bottom, c.mode == .attached ? 18 : 6)
                    }
                }
                .onChange(of: c.selectedID) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id) } }
                }
                .onChange(of: c.scrollToTopRequest) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(ListTop.id, anchor: .top) }
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
                default: EmptyState(symbol: "newspaper", title: "No posts")
                }
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    // ScrollView stacks with default spacing; keep the marker flush with the list.
                    VStack(spacing: 0) {
                        ListTop()
                        LazyVStack(spacing: 2) {
                            ForEach(Array(reader.posts.enumerated()), id: \.element.id) { i, post in
                                Group {
                                    if post.isXPost {
                                        XPostRow(post: post, selected: post.id == c.selectedPostID, selection: selection)
                                    } else {
                                        PostRow(post: post, selected: post.id == c.selectedPostID, selection: selection)
                                    }
                                }
                                    .driftScope("row.\(i)")
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
                }
                .onChange(of: c.selectedPostID) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id) } }
                }
                .onChange(of: c.scrollToTopRequest) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(ListTop.id, anchor: .top) }
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
                .driftTag("box")
                // The dot sits in an overlay, which doesn't report where it is; place it from the row.
                .driftTag(unread ? "dot" : "", rect: CGRect(x: 3, y: (compact ? 7 : 10) + 17 - 3, width: 6, height: 6))
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
                // Level with the avatar's center (row padding + half the 34pt avatar), not the row's:
                // rows grow with their text, and a centered dot drifted from row to row.
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .offset(x: 3, y: (compact ? 7 : 10) + 17 - 3)
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
                Group {
                    if gravatarHash(note.icon) != nil {
                        Avatar(url: note.icon, kind: note.kind)
                            .hovercard { PersonCard(avatar: note.icon, name: note.actor) }
                    } else {
                        Avatar(url: note.icon, kind: note.kind)
                    }
                }
                .driftTag("icon")

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        (Text(note.actor ?? "").fontWeight(.semibold)
                         + Text(note.actor == nil ? note.action : " " + note.action).foregroundStyle(.secondary))
                            .lineLimit(1)
                            .driftTag("who")
                        Spacer(minLength: 4)
                        ReminderClock(id: Reminder.id(note: note))
                        Text(note.date.map(shortTime) ?? "")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(note.isUnread ? Color.accentColor : .secondary)
                            .driftTag("time")
                    }
                    .font(.system(size: 12))

                    if let target = note.target {
                        Text(target.plainText)
                            .font(.system(size: 13, weight: note.isUnread ? .semibold : .medium))
                            .lineLimit(2)
                            .driftTag("title")
                    }
                    if let excerpt = note.excerpt, !excerpt.isEmpty {
                        Text(excerpt).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                            .driftTag("excerpt")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            }
        }
        .contextMenu {
            Button(note.isUnread ? "Mark as Read" : "Mark as Unread") {
                note.isUnread ? c.store.markRead(note) : c.store.markUnread(note)
            }
            RemindItems(id: Reminder.id(note: note)) { Reminders.shared.remind(note, at: $0) }
            Divider()
            Button("Open in Browser") { c.store.openInBrowser(note) }
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
                Group {
                    if post.isExternal {
                        SiteIcon(url: reader.icon(for: post), name: site, size: 34)
                    } else {
                        SiteIcon(url: reader.icon(for: post), name: site, size: 34)
                            .hovercard { SiteCard(id: post.site_ID, name: site, icon: reader.icon(for: post)) }
                    }
                }
                .driftTag("icon")

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(site.plainText).fontWeight(.semibold).foregroundStyle(.secondary).lineLimit(1)
                            .driftTag("who")
                        Spacer(minLength: 4)
                        ReminderClock(id: Reminder.id(post: post))
                        Text(post.dateValue.map(shortTime) ?? "")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .driftTag("time")
                    }
                    .font(.system(size: 12))

                    Text((post.title ?? "").plainText.isEmpty ? "Untitled" : (post.title ?? "").plainText)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .driftTag("title")
                    let excerpt = (post.excerpt ?? "").plainText
                    if !excerpt.isEmpty {
                        Text(excerpt).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(3)
                            .driftTag("excerpt")
                    }
                    HStack(spacing: 6) {
                        if let name = post.author?.name, !name.isEmpty, name != site {
                            Text(name)
                        }
                        if let time = post.readingTime { Text(time) }
                        if let views = reader.views(post) {
                            HStack(spacing: 2) {
                                SignalBars()
                                Text(views)
                            }
                            .help("\(views) views")
                        }
                        if let like = reader.likeState(post), like.count > 0 {
                            HStack(spacing: 2) {
                                LikeStar(liked: like.liked, size: 10, idle: .secondary)
                                Text("\(like.count)")
                                    .contentTransition(.numericText(value: Double(like.count)))
                            }
                        }
                        if let comments = post.comment_count, comments > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "bubble.left")
                                Text("\(comments)")
                            }
                            .help(comments == 1 ? "1 comment" : "\(comments) comments")
                        }
                        if reader.isSaved(post) && reader.feed != .saved { // everything in Saved is saved
                            Image(systemName: "bookmark.fill").foregroundStyle(Color.accentColor)
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary) // tertiary was too faint to read over the panel's material
                    .driftTag("foot")
                    .padding(.top, 1)
                    .task(id: post.id) { await reader.loadViews(post) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            }
        }
        .contextMenu {
            Button(reader.isSaved(post) ? "Remove from Saved" : "Save Post") { reader.toggleSave(post) }
            RemindItems(id: Reminder.id(post: post)) { Reminders.shared.remind(post, at: $0) }
            if reader.canLike(post) {
                Button(reader.likeState(post)?.liked == true ? "Unlike Post" : "Like Post") {
                    Task { await reader.toggleLike(post) }
                }
            }
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
                            .driftTag("kind", shift: CGSize(width: 4, height: 4))
                    }
                    .driftTag("icon")
                    .hovercard {
                        if let origin = post.xpostOrigin {
                            SiteCard(id: origin.site, name: source.name ?? source.handle,
                                     icon: reader.icon(forSite: origin.site))
                        }
                    }
                    .frame(width: 34)
                    .task { if let origin = post.xpostOrigin { await reader.loadIcon(forSite: origin.site) } }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(source.handle).fontWeight(.semibold)
                        Image(systemName: "arrow.right").font(.system(size: 8, weight: .bold)).foregroundStyle(.tertiary)
                        Text(post.destinationHandle)
                        if reader.isSaved(post) && reader.feed != .saved {
                            Image(systemName: "bookmark.fill").font(.system(size: 9)).foregroundStyle(Color.accentColor)
                        }
                        Spacer(minLength: 4)
                        Text(post.dateValue.map(shortTime) ?? "").monospacedDigit()
                            .driftTag("time")
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .driftTag("line")

                    Text(post.xpostTitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(2)
                        .driftTag("title")
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
                .driftTag("kind", shift: CGSize(width: 3, height: 3))
        }
    }

    private var glyph: (symbol: String, color: Color) {
        switch kind {
        case .mention: return ("at", .orange)
        case .comment: return ("bubble.left.fill", .blue)
        case .like: return ("star.fill", .like)
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
                    IconButton("xmark", help: "Close reader (esc)") { c.closeDetail() }.driftTag("detail.close")
                }
                if c.section == .reader, let post = c.selectedPost {
                    if reader.canLike(post) {
                        LikeButton(state: reader.likeState(post)) { Task { await reader.toggleLike(post) } }
                            .driftTag("detail.like")
                            .id(post.id) // a new post's like state shouldn't play the like animation
                            .task(id: post.id) { await reader.loadLikeState(for: post) }
                    }
                    IconButton(reader.isSaved(post) ? "bookmark.fill" : "bookmark",
                               help: reader.isSaved(post) ? "Remove from Saved (s)" : "Save post (s)",
                               tint: reader.isSaved(post) ? .accentColor : nil) { reader.toggleSave(post) }
                        .driftTag("detail.save")
                }
                if c.section == .reader, let post = c.selectedPost {
                    RemindMenu(id: Reminder.id(post: post)) { Reminders.shared.remind(post, at: $0) }
                } else if c.section == .notifications, let note = c.selectedNote {
                    RemindMenu(id: Reminder.id(note: note)) { Reminders.shared.remind(note, at: $0) }
                }
                IconButton("safari", help: "Open in browser (o)") { c.openSelectedInBrowser() }
                    .driftTag("detail.open")
                    .disabled(c.selectedNote == nil && c.selectedPost == nil)
                Spacer()
                // Prev/next sit on the right, next to the list they step through.
                if let p = c.position {
                    Text("\(p.index + 1) of \(p.count)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .driftTag("detail.pos")
                        .padding(.trailing, 4)
                }
                IconButton("chevron.up", help: "Previous (k)") { c.move(-1) }
                    .driftTag("detail.prev")
                    .disabled((c.position?.index ?? 0) == 0)
                IconButton("chevron.down", help: "Next (j)") { c.move(1) }
                    .driftTag("detail.next")
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
            // Folded away rather than removed, so the article doesn't reload when it comes back.
            .frame(maxHeight: c.commentsOpen && c.commentsExpanded && c.commentTarget != nil ? 0 : .infinity)
            .clipped()

            if let t = c.commentTarget {
                // Not re-identified per post: the drawer stays put and swaps its thread.
                CommentsDrawer(site: t.site, post: t.post)
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
    @State private var replyTo: PostComment?
    @State private var draft = ""
    @State private var sending = false
    @State private var sendError: String?
    /// Moving to another post while its thread loads: the old one stays, dimmed, so nothing jumps.
    @State private var switching = false
    @FocusState private var composing: Bool
    @Namespace private var ns

    private let spring = Animation.spring(response: 0.48, dampingFraction: 0.8)
    private var key: String { "\(site)-\(post)" }

    var body: some View {
        // A real (zero-height) view so `.task` runs before there's anything to show.
        VStack(spacing: 0) {
            Color.clear.frame(height: 0)
            if let comments {
                VStack(spacing: 0) {
                    Divider().opacity(0.6)
                    header(comments.count)
                    if c.commentsOpen {
                        if !comments.isEmpty { list(comments) }
                        composer
                    } else if !comments.isEmpty {
                        strip(comments)
                    }
                }
                .background(Color.primary.opacity(0.025))
                .opacity(switching ? 0.45 : 1)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: c.replyRequest) { _, _ in replyFromKeyboard() }
        .task(id: key) {
            // First time: slide up and pop the bubbles in. After that, just swap threads.
            guard comments != nil else {
                let loaded = await reader.comments(site: site, post: post)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { comments = loaded }
                try? await Task.sleep(for: .milliseconds(60))
                appeared = true
                await refresh()
                return
            }
            replyTo = nil
            draft = ""
            sendError = nil
            focus = nil
            if let cached = reader.cachedComments(site: site, post: post) {
                comments = cached
                switching = false
            } else {
                withAnimation(.easeOut(duration: 0.12)) { switching = true }
                comments = await reader.comments(site: site, post: post)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.12)) { switching = false }
            }
            await refresh()
        }
    }

    /// `r`: the composer, replying to the notification's comment when it's a comment notification.
    private func replyFromKeyboard() {
        let commentID = c.section == .notifications ? c.selectedNote?.meta?.ids?.comment : nil
        startReply(to: commentID.flatMap { id in comments?.first { $0.id == id } })
    }

    /// Swaps in the latest thread. What was showing came from a cache that may be well behind.
    private func refresh() async {
        let latest = await reader.comments(site: site, post: post, fresh: true)
        guard !Task.isCancelled, let current = comments,
              latest.map(\.id) != current.map(\.id) || latest.map(\.likeCount) != current.map(\.likeCount) else { return }
        withAnimation(spring) { comments = latest }
    }

    private func toggle(focusing id: Int? = nil) {
        focus = id
        withAnimation(spring) { c.commentsOpen.toggle() }
    }

    /// Opens the list with the comment box focused, replying to `comment` (or the post).
    private func startReply(to comment: PostComment?) {
        replyTo = comment
        sendError = nil
        if !c.commentsOpen { focus = comment?.id; withAnimation(spring) { c.commentsOpen = true } }
        DispatchQueue.main.async { composing = true }
    }

    private func toggleLike(_ comment: PostComment) {
        guard let i = comments?.firstIndex(where: { $0.id == comment.id }) else { return }
        let like = !comment.iLike
        // Flip it right away; settle on WordPress.com's count when it answers.
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            comments?[i].iLike = like
            comments?[i].likeCount += like ? 1 : -1
        }
        Task {
            let result = try? await reader.setLike(like, comment: comment.id, site: site)
            guard let j = comments?.firstIndex(where: { $0.id == comment.id }) else { return }
            comments?[j].iLike = result?.iLike ?? !like
            comments?[j].likeCount = result?.count ?? comment.likeCount
            if let comments { reader.storeComments(comments, site: site, post: post) }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }
        sending = true
        sendError = nil
        Task {
            defer { sending = false }
            do {
                var new = try await reader.postComment(text, site: site, post: post, replyingTo: replyTo?.id)
                var list = comments ?? []
                // Replies go after the parent's existing replies; new comments go at the end.
                if let parent = replyTo, let p = list.firstIndex(where: { $0.id == parent.id }) {
                    new.depth = list[p].depth + 1
                    var at = p + 1
                    while at < list.count, list[at].depth > list[p].depth { at += 1 }
                    list.insert(new, at: at)
                } else {
                    list.append(new)
                }
                withAnimation(spring) { comments = list }
                reader.storeComments(list, site: site, post: post)
                focus = new.id
                draft = ""
                replyTo = nil
            } catch {
                sendError = error.localizedDescription
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let replyTo {
                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.left.fill").font(.system(size: 9))
                    Text("Replying to \(replyTo.author?.name ?? "comment")").lineLimit(1)
                    Button { self.replyTo = nil } label: { Image(systemName: "xmark").font(.system(size: 8, weight: .bold)) }
                        .buttonStyle(.plain)
                        .help("Comment on the post instead")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(replyTo == nil ? "Add a comment…" : "Write a reply…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .lineLimit(1...6)
                    .focused($composing)
                    .disabled(sending)
                    .onExitCommand { if replyTo != nil { replyTo = nil } else { composing = false } }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(composing ? 0.5 : 0), lineWidth: 1))
                    .driftTag("comments.field")
                Button(action: send) {
                    if sending {
                        ProgressView().controlSize(.small).frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 24))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary.opacity(0.4) : Color.accentColor)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Send (⌘↩)")
            }
            if let sendError {
                Text(sendError).font(.system(size: 11)).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 18) // clears the panel's resize handle
    }

    private func header(_ count: Int) -> some View {
        Button { toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                Text(count == 0 ? "Add a comment" : count == 1 ? "1 comment" : "\(count) comments")
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
            .driftTag("comments.head")
        }
        .buttonStyle(.plain)
        .help(c.commentsOpen ? "Hide comments" : "Show comments")
        .overlay(alignment: .trailing) {
            if c.commentsOpen {
                // Left of the chevron: comments over the whole reader, or back to sharing it with the post.
                IconButton(c.commentsExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                           help: c.commentsExpanded ? "Show the post too" : "Comments full height") {
                    withAnimation(spring) { c.commentsExpanded.toggle() }
                }
                .driftTag("comments.expand")
                .padding(.trailing, 36)
                .transition(.opacity)
            }
        }
    }

    private func strip(_ comments: [PostComment]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(comments.enumerated()), id: \.element.id) { i, comment in
                    Button { toggle(focusing: comment.id) } label: {
                        CommentBubble(comment: comment, expanded: false, ns: ns)
                            .driftTag("comments.bubble.\(i)")
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
                Button { startReply(to: nil) } label: {
                    Image(systemName: "plus.bubble")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                        .driftTag("comments.add")
                }
                .buttonStyle(.plain)
                .help("Add a comment")
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(Double(min(comments.count, 14)) * 0.045), value: appeared)
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 14)
            .background(WheelScrollsSideways())
        }
        .id(key) // each thread starts scrolled to its first comment
    }

    private func list(_ comments: [PostComment]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            CommentBubble(comment: comment, expanded: true, ns: ns)
                            CommentActions(comment: comment, replying: replyTo?.id == comment.id,
                                           like: { toggleLike(comment) }, reply: { startReply(to: comment) })
                                .padding(.leading, 47) // lined up with the bubble's text, clear of its rounded corner
                        }
                        .padding(.leading, CGFloat(min(comment.depth, 3)) * 24)
                        .id(comment.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .id(key)
            .frame(maxHeight: .infinity)
            .driftTag("comments.list")
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
            .hovercard(edge: .top) { PersonCard(avatar: comment.author?.avatar_URL, name: comment.author?.name) }
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
                    .lineSpacing(expanded ? 3.5 : 2)
                    .lineLimit(expanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(width: expanded ? nil : 190, alignment: .leading)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 14,
                                       bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                    .matchedGeometryEffect(id: "bubble\(comment.id)", in: ns)
            )
        }
        // Short comments get short bubbles; long ones wrap at the drawer's width.
        .frame(maxWidth: expanded ? .infinity : nil, alignment: .leading)
        .padding(.top, 2)
    }
}

/// Like and Reply, under a comment in the open list.
struct CommentActions: View {
    let comment: PostComment
    let replying: Bool
    let like: () -> Void
    let reply: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: like) {
                HStack(spacing: 3) {
                    LikeStar(liked: comment.iLike, size: 11)
                    if comment.likeCount > 0 {
                        Text("\(comment.likeCount)").monospacedDigit()
                            .contentTransition(.numericText(value: Double(comment.likeCount)))
                    }
                }
            }
            .help(comment.iLike ? "Unlike" : "Like")
            Button(action: reply) { Text("Reply") }
                .foregroundStyle(replying ? Color.accentColor : Color.secondary)
                .help("Reply to \(comment.author?.name ?? "this comment")")
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
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
            Text(reader ? "↑ ↓ or j k to move · l to like · s to save · o to open" : "↑ ↓ or j k to move · o to open in browser")
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
            ForEach(options.indices, id: \.self) { i in segment(options[i]).driftTag("pill.\(i)") }
        }
        .padding(2)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
        .driftTag("pills")
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

/// Heart and count for the open post. Dimmed until an x-post's original has been looked up.
/// Views: four thin bars rising like a signal meter. SF's `cellularbars` is too heavy at 11pt.
struct SignalBars: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 1.4) {
            ForEach([0.36, 0.57, 0.79, 1.0], id: \.self) { h in
                Capsule().frame(width: 1.6, height: 9 * h)
            }
        }
        .frame(height: 9)
        .padding(.trailing, 1)
        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 0.5 }
    }
}

extension Color {
    /// A liked star: WordPress.com's golden yellow, dark enough to read on a light background.
    static let like = Color(red: 0.96, green: 0.69, blue: 0.0)
}

struct LikeButton: View {
    let state: ReaderStore.LikeState?
    let action: () -> Void

    var body: some View {
        let liked = state?.liked ?? false
        Button(action: action) {
            HStack(spacing: 3) {
                LikeStar(liked: state?.liked, size: 14)
                if let count = state?.count, count > 0 {
                    Text("\(count)").font(.system(size: 11, weight: .medium).monospacedDigit())
                        .contentTransition(.numericText(value: Double(count)))
                }
            }
            .foregroundStyle(liked ? Color.like : Color.secondary)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: state?.count)
            .padding(.horizontal, 5)
            .frame(minWidth: 26, minHeight: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state == nil)
        .opacity(state == nil ? 0.4 : 1)
        .help(liked ? "Unlike (l)" : "Like (l)")
    }
}

/// WordPress.com likes are stars. Liking one spins it a fifth of a turn (so it lands on itself),
/// pops it big and throws a ring of sparks; unliking squashes it and gives it a wobble.
/// Only real changes animate: a nil (still loading) state, or a new view identity, doesn't.
struct LikeStar: View {
    let liked: Bool?
    var size: CGFloat = 12
    var idle: Color = .secondary
    @State private var likes = 0
    @State private var unlikes = 0

    private struct Pop { var scale = 1.0; var angle = 0.0; var squash = 1.0 }

    var body: some View {
        let on = liked ?? false
        Image(systemName: on ? "star.fill" : "star")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(on ? Color.like : idle)
            .keyframeAnimator(initialValue: Pop(), trigger: likes) { star, p in
                star.scaleEffect(p.scale).rotationEffect(.degrees(p.angle))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.55, duration: 0.09)
                    SpringKeyframe(1.55, duration: 0.2, spring: .snappy)
                    SpringKeyframe(1, duration: 0.45, spring: .bouncy(extraBounce: 0.25))
                }
                KeyframeTrack(\.angle) {
                    CubicKeyframe(-24, duration: 0.09)
                    SpringKeyframe(72, duration: 0.6, spring: .bouncy(extraBounce: 0.2))
                }
            }
            .keyframeAnimator(initialValue: Pop(), trigger: unlikes) { star, p in
                star.scaleEffect(x: p.scale, y: p.scale * p.squash).rotationEffect(.degrees(p.angle))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.7, duration: 0.1)
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                }
                KeyframeTrack(\.squash) {
                    CubicKeyframe(0.75, duration: 0.1)
                    SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                }
                KeyframeTrack(\.angle) {
                    CubicKeyframe(-14, duration: 0.08)
                    CubicKeyframe(10, duration: 0.1)
                    CubicKeyframe(-5, duration: 0.09)
                    CubicKeyframe(0, duration: 0.1)
                }
            }
            .background { LikeSparks(trigger: likes, radius: size * 1.5) }
            .onChange(of: liked) { old, new in
                guard let old, let new, old != new else { return }
                if new { likes += 1 } else { unlikes += 1 }
            }
    }
}

/// The burst behind a new like: a ring that opens out and a handful of sparks flying off it.
private struct LikeSparks: View {
    let trigger: Int
    let radius: CGFloat
    private static let colors: [Color] = [.like, .orange, .yellow, .pink, .like, .orange, .mint, .yellow]

    var body: some View {
        // `t` runs 0→1 on each like and rests at 1, where everything is invisible.
        Color.clear.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, t in
            let live = t < 1
            ZStack {
                Circle()
                    .strokeBorder(Color.like.opacity(live ? 0.55 * (1 - t) : 0), lineWidth: max(0.5, 2.5 * (1 - t)))
                    .frame(width: radius * 2 * (0.4 + 0.8 * t), height: radius * 2 * (0.4 + 0.8 * t))
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) / 8 * 2 * .pi - .pi / 2
                    let reach = radius * (0.5 + 0.9 * t)
                    Group {
                        if i.isMultiple(of: 2) {
                            Image(systemName: "star.fill").font(.system(size: radius * 0.42))
                        } else {
                            Circle().frame(width: radius * 0.26, height: radius * 0.26)
                        }
                    }
                    .foregroundStyle(Self.colors[i])
                    .scaleEffect(live ? 1.2 - t : 0)
                    .opacity(live ? 1 - t * t : 0)
                    .offset(x: cos(angle) * reach, y: sin(angle) * reach)
                }
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        } keyframes: { _ in
            MoveKeyframe(0)
            CubicKeyframe(0.15, duration: 0.07) // hold back while the star squashes
            CubicKeyframe(1, duration: 0.55)
        }
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
            // The whole bottom edge drags, but the grip stays centered under the list, which is
            // the part hanging from the menu bar. Centered on the full panel it landed under the
            // reader, next to the divider.
            Capsule()
                .fill(Color.primary.opacity(hovering || dragging ? 0.4 : 0.14))
                .frame(width: dragging ? 48 : 36, height: 4)
                .driftTag("grip")
                .frame(width: c.listWidth)
                .frame(maxWidth: .infinity, alignment: .trailing)
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
