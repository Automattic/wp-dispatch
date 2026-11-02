import AppKit
import UserNotifications

/// Mac notifications: a banner for each new WordPress.com notification of the kinds you pick, with
/// Reply, Mark as Read and Remind Me in 1 Hour right on it, and the banners for `Reminders`.
@MainActor
final class Alerts: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Alerts()
    weak var controller: PanelController?

    /// Lazy: it can't exist outside an app bundle, which demo mode runs without.
    private lazy var center = UNUserNotificationCenter.current()

    /// Which notifications get a banner. Mentions and comments by default; likes and follows are noise.
    enum Kind: String, CaseIterable {
        case mention, comment, like, follow
        var title: String {
            switch self {
            case .mention: "Mentions"
            case .comment: "Comments and Replies"
            case .like: "Likes"
            case .follow: "Follows"
            }
        }
        init?(_ k: Note.Kind) {
            switch k {
            case .mention: self = .mention
            case .comment: self = .comment
            case .like: self = .like
            case .follow: self = .follow
            case .other: return nil
            }
        }
    }

    func isOn(_ kind: Kind) -> Bool {
        UserDefaults.standard.object(forKey: "alert.\(kind.rawValue)") as? Bool ?? (kind == .mention || kind == .comment)
    }

    func set(_ kind: Kind, _ on: Bool) {
        UserDefaults.standard.set(on, forKey: "alert.\(kind.rawValue)")
        if on { requestPermission() }
    }

    func start(_ controller: PanelController) {
        guard !Demo.isOn else { return }
        self.controller = controller
        center.delegate = self
        let read = UNNotificationAction(identifier: "read", title: "Mark as Read")
        let later = UNNotificationAction(identifier: "later", title: "Remind Me in 1 Hour")
        let reply = UNTextInputNotificationAction(identifier: "reply", title: "Reply", options: [],
                                                  textInputButtonTitle: "Send", textInputPlaceholder: "Write a reply…")
        let snooze = UNNotificationAction(identifier: "snooze", title: "Remind Me in 1 Hour")
        let done = UNNotificationAction(identifier: "done", title: "Done")
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "note.reply", actions: [reply, read, later], intentIdentifiers: []),
            UNNotificationCategory(identifier: "note", actions: [read, later], intentIdentifiers: []),
            UNNotificationCategory(identifier: "reminder", actions: [snooze, done], intentIdentifiers: []),
        ])
        if Kind.allCases.contains(where: isOn) || !Reminders.shared.all.isEmpty { requestPermission() }
    }

    private func requestPermission() {
        guard !Demo.isOn else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: New notifications

    /// Called after each refresh. Banners only for what arrived since the last one we saw, so
    /// launching (or the first run) never replays the backlog. A burst becomes one summary banner.
    func announce(_ notes: [Note]) {
        guard !Demo.isOn, controller != nil, let newest = notes.compactMap(\.date).max() else { return }
        let key = "alertedThrough"
        defer { UserDefaults.standard.set(newest.timeIntervalSince1970, forKey: key) }
        guard let seen = UserDefaults.standard.object(forKey: key) as? Double else { return }
        let fresh = notes.filter {
            $0.isUnread && ($0.date?.timeIntervalSince1970 ?? 0) > seen && Kind($0.kind).map(isOn) == true
        }
        if fresh.count > 4 {
            let content = UNMutableNotificationContent()
            content.title = "\(fresh.count) new notifications"
            content.body = fresh.prefix(3).compactMap { [$0.actor, $0.action, $0.target].compactMap { $0 }.joined(separator: " ") }.joined(separator: "\n")
            content.sound = .default
            deliver("summary-\(newest.timeIntervalSince1970)", content)
            return
        }
        for note in fresh.reversed() { post(note) }
    }

    private func post(_ note: Note) {
        let content = UNMutableNotificationContent()
        content.title = [note.actor, note.action].compactMap { $0 }.joined(separator: " ")
        if let target = note.target { content.subtitle = target }
        if let excerpt = note.excerpt { content.body = excerpt }
        content.sound = .default
        content.threadIdentifier = note.meta?.ids?.post.map(String.init) ?? "dispatch"
        content.userInfo = ["note": note.id]
        // Comments and mentions can be answered from the banner.
        let canReply = note.meta?.ids?.post != nil && (note.kind == .comment || note.kind == .mention)
        content.categoryIdentifier = canReply ? "note.reply" : "note"
        deliver("note-\(note.id)", content)
    }

    private func deliver(_ id: String, _ content: UNMutableNotificationContent, at date: Date? = nil) {
        let trigger = date.map {
            UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: $0),
                                          repeats: false)
        }
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: Sign-in

    /// WordPress.com sign-ins last about two weeks and can't renew themselves. Once one runs out
    /// nothing updates, so say so instead of going quiet. Clicking it opens the panel's Reconnect.
    func sessionExpired() {
        guard !Demo.isOn else { return }
        // At launch this runs before `start`; let that set the delegate first.
        DispatchQueue.main.async { [self] in
            requestPermission()
            let content = UNMutableNotificationContent()
            content.title = "Reconnect Dispatch to WordPress.com"
            content.body = "Your sign-in expired, so notifications have stopped. Click to sign in again."
            content.sound = .default
            deliver("session-expired", content)
        }
    }

    // MARK: Reminders

    func schedule(_ r: Reminder) {
        guard !Demo.isOn else { return }
        requestPermission()
        let content = UNMutableNotificationContent()
        content.title = r.title
        if let subtitle = r.subtitle { content.subtitle = subtitle }
        content.body = "You asked to be reminded about this."
        content.sound = .default
        content.categoryIdentifier = "reminder"
        content.userInfo = ["reminder": r.id]
        unschedule(r.id)
        deliver("reminder-\(r.id)", content, at: max(r.due, .now.addingTimeInterval(1)))
    }

    func unschedule(_ id: String) {
        guard !Demo.isOn else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["reminder-\(id)"])
        center.removeDeliveredNotifications(withIdentifiers: ["reminder-\(id)"])
    }

    // MARK: UNUserNotificationCenterDelegate

    // Banners show even while Dispatch is the active app.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler done: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let noteID = info["note"] as? Int
        let reminderID = info["reminder"] as? String
        let action = response.actionIdentifier
        let text = (response as? UNTextInputNotificationResponse)?.userText
        Task { @MainActor in
            self.handle(action, note: noteID, reminder: reminderID, text: text)
            done()
        }
    }

    private func handle(_ action: String, note noteID: Int?, reminder reminderID: String?, text: String?) {
        guard let c = controller else { return }
        let note = noteID.flatMap { id in c.store.notes.first { $0.id == id } }
        switch action {
        case "reply":
            guard let note, let site = note.meta?.ids?.site, let post = note.meta?.ids?.post,
                  let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
            c.store.markRead(note)
            Task { _ = try? await c.reader.postComment(text, site: site, post: post, replyingTo: note.meta?.ids?.comment) }
        case "read":
            if let note { c.store.markRead(note) }
        case "later":
            if let note { Reminders.shared.remind(note, at: .now.addingTimeInterval(3600)) }
        case "snooze":
            if let reminderID { Reminders.shared.snooze(reminderID, until: .now.addingTimeInterval(3600)) }
        case "done":
            if let reminderID { Reminders.shared.cancel(reminderID) }
        default: // clicked the banner itself
            if let reminderID, let r = Reminders.shared.reminder(reminderID) { c.open(r) }
            else if let note { c.open(note) }
            else { c.reopen() }
        }
    }
}
