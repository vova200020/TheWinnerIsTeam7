import EventKit
import Foundation
import Observation

/// Scheduled sessions (spec §3.1 entry point 2): calendar events tagged #focus
/// are sent to the watch as `schedule`, with a reminder notification at start time.
@MainActor
@Observable
final class CalendarSync {
    struct Planned: Identifiable, Equatable {
        let id: String
        let title: String
        let tag: String
        let start: Date
        let minutes: Int
    }

    var upcoming: [Planned] = []
    var accessGranted = false
    var error: String?

    private let store = EKEventStore()
    static let marker = "#focus"
    static let tags = ["studying", "journaling", "writing", "coding", "reading"]

    func requestAccess() async {
        do {
            accessGranted = try await store.requestFullAccessToEvents()
            if accessGranted { reload() }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reload() {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        accessGranted = true
        let start = Date.now
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        upcoming = store.events(matching: predicate)
            .filter { Self.isFocus($0) }
            .prefix(10)
            .map { e in
                Planned(id: e.eventIdentifier ?? UUID().uuidString,
                        title: e.title.replacingOccurrences(of: Self.marker, with: "").trimmingCharacters(in: .whitespaces),
                        tag: Self.tag(for: e),
                        start: e.startDate,
                        minutes: max(1, Int(e.endDate.timeIntervalSince(e.startDate) / 60)))
            }
        for p in upcoming {
            Notifier.scheduleFocusReminder(id: p.id, title: p.title.isEmpty ? p.tag.capitalized : p.title, at: p.start)
        }
    }

    /// `{ "t": "schedule", "sessions": [ { "start", "len", "tag" } ] }` (spec §4.2)
    var scheduleMessage: [String: Any] {
        [
            "t": "schedule",
            "sessions": upcoming.prefix(5).map {
                ["start": Int($0.start.timeIntervalSince1970), "len": $0.minutes, "tag": $0.tag] as [String: Any]
            },
        ]
    }

    private static func isFocus(_ e: EKEvent) -> Bool {
        let text = ((e.title ?? "") + " " + (e.notes ?? "")).lowercased()
        return text.contains(marker)
    }

    private static func tag(for e: EKEvent) -> String {
        let text = ((e.title ?? "") + " " + (e.notes ?? "")).lowercased()
        return tags.first { text.contains($0) } ?? "other"
    }
}
