import Foundation

/// "Remind me about this later" for a notification or a post. A reminder is a local Mac
/// notification scheduled for its time (see `Alerts`), plus this list, which keeps what it takes to
/// reopen the item and marks its row with a clock until you open it or say you're done.
struct Reminder: Codable, Identifiable, Equatable {
    /// "n<note ID>" or "p<post ID>", so an item has one reminder at a time.
    let id: String
    var due: Date
    let title: String
    let subtitle: String?
    let noteID: Int?
    let post: ReaderPost?
    let url: String?

    static func id(note: Note) -> String { "n\(note.id)" }
    static func id(post: ReaderPost) -> String { "p\(post.id)" }

    static func == (a: Reminder, b: Reminder) -> Bool { a.id == b.id && a.due == b.due }
}

@MainActor
final class Reminders: ObservableObject {
    static let shared = Reminders()

    @Published private(set) var all: [Reminder] = []

    private static let file = AppData.directory.appendingPathComponent("reminders.json")

    private init() {
        if let data = try? Data(contentsOf: Self.file), let list = try? JSONDecoder().decode([Reminder].self, from: data) {
            all = list.sorted { $0.due < $1.due }
        }
    }

    func reminder(_ id: String) -> Reminder? { all.first { $0.id == id } }

    func remind(_ note: Note, at due: Date) {
        add(Reminder(id: Reminder.id(note: note), due: due,
                     title: [note.actor, note.action].compactMap { $0 }.joined(separator: " "),
                     subtitle: note.target, noteID: note.id, post: nil, url: note.url))
    }

    func remind(_ post: ReaderPost, at due: Date) {
        let title = (post.title ?? "").plainText
        add(Reminder(id: Reminder.id(post: post), due: due, title: title.isEmpty ? "A post" : title,
                     subtitle: post.site_name, noteID: nil, post: post, url: post.URL))
    }

    /// Done with it, or changed your mind.
    func cancel(_ id: String) {
        all.removeAll { $0.id == id }
        Alerts.shared.unschedule(id)
        save()
    }

    func snooze(_ id: String, until due: Date) {
        guard let r = reminder(id) else { return }
        var later = r
        later.due = due
        add(later)
    }

    private func add(_ r: Reminder) {
        all.removeAll { $0.id == r.id }
        all.append(r)
        all.sort { $0.due < $1.due }
        Alerts.shared.schedule(r)
        save()
    }

    private func save() {
        guard !Demo.isOn, let data = try? JSONEncoder().encode(all) else { return }
        try? data.write(to: Self.file, options: .atomic)
    }

    // MARK: When

    struct Choice: Identifiable {
        let title: String
        let due: Date
        var id: String { title }
    }

    /// The times on offer, from now: soon, later today, tomorrow, next week.
    static func choices(from now: Date = .now) -> [Choice] {
        let cal = Calendar.current
        func at(_ hour: Int, daysAhead: Int = 0) -> Date {
            let day = cal.date(byAdding: .day, value: daysAhead, to: now) ?? now
            return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }
        var list = [Choice(title: "In 1 Hour", due: now.addingTimeInterval(3600)),
                    Choice(title: "In 3 Hours", due: now.addingTimeInterval(3 * 3600))]
        if cal.component(.hour, from: now) < 17 { list.append(Choice(title: "This Evening", due: at(18))) }
        list.append(Choice(title: "Tomorrow Morning", due: at(9, daysAhead: 1)))
        let monday = cal.nextDate(after: now, matching: DateComponents(hour: 9, weekday: 2), matchingPolicy: .nextTime) ?? at(9, daysAhead: 7)
        list.append(Choice(title: "Next Week", due: monday))
        return list
    }

    /// "Today at 6:00 PM", "Tomorrow at 9:00 AM", "Mon at 9:00 AM".
    static func describe(_ date: Date) -> String {
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date) { return "Today at \(time)" }
        if cal.isDateInTomorrow(date) { return "Tomorrow at \(time)" }
        return "\(date.formatted(.dateTime.weekday(.abbreviated))) at \(time)"
    }
}
