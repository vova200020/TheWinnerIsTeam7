import CoreLocation
import Foundation
import Observation

struct SessionRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var seconds: Int
    var avgScore: Int
    var selfReport: Int
    var tag: String
    var level: DetoxLevel
    // Rich fields from the watch's session_end (optional: older records lack them).
    var plannedMinutes: Int?
    var peak: Int?
    var low: Int?
    var breaks: Int?
    var dips: Int?
    var fadeMinute: Int?
    var hrAvg: Int?
    var hrMax: Int?
    var hrv: Int?
    var curve: [Int]?
    var curveStep: Int?
    var threshold: Int?
    var xp: Int?
    var awards: [String]?
    // Exact fix stays on this phone; only `cell` (geohash-7, ~150 m) is ever shown or shared.
    var lat: Double?
    var lon: Double?
    var locationSource: String?   // "watch GPS" | "phone"
    var notes: String?

    var cell: String? {
        guard let lat, let lon else { return nil }
        return Geohash.encode(CLLocationCoordinate2D(latitude: lat, longitude: lon), precision: 7)
    }

    var minutes: Int { seconds / 60 }
    /// (minute, score) points for charts.
    var curvePoints: [(minute: Double, score: Int)] {
        let step = Double(curveStep ?? 60) / 60
        return (curve ?? []).enumerated().map { (Double($0.offset + 1) * step, $0.element) }
    }
    /// Minutes at or above the user's focus line.
    var minutesInZone: Int {
        let th = threshold ?? 65
        let step = Double(curveStep ?? 60) / 60
        return Int((Double((curve ?? []).filter { $0 >= th }.count) * step).rounded())
    }
}

/// Glues the watch protocol (spec §4.2) to Screen Time, the calendar and history.
@MainActor
@Observable
final class AppModel {
    let watch = WatchLink()
    let detox = DetoxManager()
    let calendar = CalendarSync()

    var session: SessionState? = SharedStore.session
    var history: [SessionRecord] = AppModel.loadHistory()
    var sharedSpots: [SharedSpot] = AppModel.loadSpots()
    /// Phone location taken at session start: fallback when the watch had no GPS fix (indoors).
    let phoneLocation = Locator()
    var banner: String?

    init() {
        watch.onMessage = { [weak self] in self?.handle($0) }
    }

    func start() {
        watch.start()
        Notifier.requestPermission()
        calendar.reload()
        detox.refresh()
        // Launch argument `-demoStart deep|medium|light` starts a pretend session (rehearsal/screenshots).
        if let level = UserDefaults.standard.string(forKey: "demoStart").flatMap(DetoxLevel.init(rawValue:)) {
            simulateStart(level: level)
        }
        // `-demoHistory 1` seeds a believable week of sessions (screenshots / pitch).
        if UserDefaults.standard.bool(forKey: "demoHistory"), history.isEmpty {
            seedDemoHistory()
        }
    }

    /// App came to the foreground (or was opened from the unlock notification).
    func becameActive() {
        session = SharedStore.session
        detox.refresh()
        calendar.reload()
        forwardPendingUnlock()
    }

    // MARK: Watch → phone

    func handle(_ msg: [String: Any]) {
        switch msg["t"] as? String {
        case "session_start":
            let s = SessionState(tag: (msg["tag"] as? String) ?? "focus",
                                 level: DetoxLevel(watchName: msg["level"] as? String),
                                 startedAt: .now,
                                 plannedMinutes: (msg["len"] as? NSNumber)?.intValue ?? 0)
            session = s
            detox.begin(s)
            phoneLocation.request()
            banner = s.level == .light
                ? "Focus started. Turn on Do Not Disturb for Light mode."
                : "\(s.level.title) focus started. Distractions are blocked."

        case "session_end":
            if let record = Self.record(from: msg, session: session, fallback: phoneLocation.coordinate) {
                history.insert(record, at: 0)
                saveHistory()
                if let goal = (msg["goal"] as? NSNumber)?.intValue { weeklyGoal = goal }
                banner = "Saved: \(record.minutes) min of \(record.tag), +\(record.xp ?? 0) XP"
            } else {
                banner = "Session ended. Apps are unblocked."
            }
            session = nil
            detox.end()

        case "unlock_granted":
            let mins = (msg["mins"] as? NSNumber)?.intValue ?? 5
            banner = detox.grantUnlock(minutes: mins)
                ? "Unlocked for \(mins) min. Earned it!"
                : "Unlock granted, but no app was waiting."

        default:
            break
        }
    }

    /// Builds a record from session_end. Works even if the phone missed session_start.
    static func record(from msg: [String: Any], session: SessionState?,
                       fallback: CLLocationCoordinate2D? = nil) -> SessionRecord? {
        func int(_ k: String) -> Int? { (msg[k] as? NSNumber)?.intValue }
        func dbl(_ k: String) -> Double? { (msg[k] as? NSNumber)?.doubleValue }
        let dur = int("dur") ?? 0
        guard dur >= 60, int("discarded") == nil else { return nil }
        let start = int("start").map { Date(timeIntervalSince1970: TimeInterval($0)) }
            ?? session?.startedAt ?? Date.now.addingTimeInterval(TimeInterval(-dur))
        let awards = (msg["awards"] as? String)?.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        return SessionRecord(
            date: start, seconds: dur, avgScore: int("avg") ?? 0, selfReport: int("self") ?? 0,
            tag: (msg["tag"] as? String) ?? session?.tag ?? "focus",
            level: (msg["level"] as? String).map { DetoxLevel(watchName: $0) } ?? session?.level ?? .light,
            plannedMinutes: int("len"), peak: int("peak"), low: int("low"), breaks: int("breaks"),
            dips: int("nudges"), fadeMinute: int("fade").flatMap { $0 >= 0 ? $0 : nil },
            hrAvg: int("hr").flatMap { $0 > 0 ? $0 : nil }, hrMax: int("hrmax").flatMap { $0 > 0 ? $0 : nil },
            hrv: int("hrv").flatMap { $0 > 0 ? $0 : nil },
            curve: (msg["curve"] as? [NSNumber])?.map(\.intValue), curveStep: int("step"),
            threshold: int("th"), xp: int("xp"), awards: awards,
            lat: dbl("lat") ?? fallback?.latitude, lon: dbl("lon") ?? fallback?.longitude,
            locationSource: dbl("lat") != nil ? "watch GPS" : (fallback != nil ? "phone" : nil))
    }

    // MARK: Notes & sharing

    func updateNotes(_ id: UUID, _ text: String) {
        guard let i = history.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        history[i].notes = trimmed.isEmpty ? nil : trimmed
        saveHistory()
        if let j = sharedSpots.firstIndex(where: { $0.id == id }) {
            sharedSpots[j].note = history[i].notes
            saveSpots()
        }
    }

    func isOnMap(_ id: UUID) -> Bool { sharedSpots.contains { $0.id == id } }

    /// "Add to focus map": publishes the cell, score, minutes, tag and note. Never the exact point.
    func toggleOnMap(_ r: SessionRecord) {
        if let i = sharedSpots.firstIndex(where: { $0.id == r.id }) {
            sharedSpots.remove(at: i)
            banner = "Removed from the focus map."
        } else if let cell = r.cell {
            sharedSpots.append(SharedSpot(id: r.id, cell: cell, tag: r.tag, score: r.avgScore,
                                          minutes: r.minutes, note: r.notes, date: r.date))
            banner = "Added to the focus map (area \(cell), ~150 m)."
        }
        saveSpots()
    }

    // MARK: Phone → watch

    /// The shield's "Unlock with watch" parked a request; send the HR challenge.
    func forwardPendingUnlock() {
        guard let pending = SharedStore.pendingUnlock, session != nil else { return }
        guard Date.now.timeIntervalSince(pending.requestedAt) < 10 * 60 else {
            SharedStore.pendingUnlock = nil
            return
        }
        watch.send(["t": "unlock_request", "app": pending.appLabel])
        banner = "Check your watch: raise your heart rate to unlock."
    }

    func sendSchedule() {
        watch.send(calendar.scheduleMessage)
        banner = "Sent \(calendar.upcoming.count) planned session(s) to the watch."
    }

    /// Escape hatch: the phone must never stay locked because the watch is gone.
    func endBlockingNow() {
        session = nil
        detox.end()
        banner = "Blocking stopped."
    }

    // MARK: Demo without a watch (simulator / pitch)

    func simulateStart(level: DetoxLevel) {
        handle(["t": "session_start", "tag": "coding", "level": level.rawValue, "len": 25])
    }

    func simulateEnd() {
        // A realistic 25-min session: warm-up, a strong stretch, a dip at ~17 min, a recovery.
        let curve = [58, 63, 68, 72, 76, 79, 81, 83, 84, 82, 80, 78, 74, 69, 63, 58, 55, 57, 64, 70, 74, 77, 78, 76, 74]
        handle(["t": "session_end", "dur": 1520, "avg": 72, "self": 4, "tag": session?.tag ?? "coding",
                "level": session?.level.rawValue ?? "deep", "start": Int(Date.now.timeIntervalSince1970) - 1520,
                "len": 25, "peak": 84, "low": 55, "breaks": 1, "nudges": 1, "fade": 16, "hr": 66, "hrmax": 98,
                "hrv": 48, "curve": curve, "step": 60, "th": 70, "xp": 47, "awards": "Deep Diver",
                "lat": phoneLocation.coordinate?.latitude ?? 37.7793, "lon": phoneLocation.coordinate?.longitude ?? -122.4193,
                "week": weekRecords.count + 1, "goal": weeklyGoal])
    }

    private func seedDemoHistory() {
        let samples: [(daysAgo: Int, hour: Int, tag: String, level: String, min: Int, curve: [Int], selfR: Int, fade: Int)] = [
            (0, 9, "coding", "deep", 25, [58, 63, 68, 72, 76, 79, 81, 83, 84, 82, 80, 78, 74, 69, 63, 58, 55, 57, 64, 70, 74, 77, 78, 76, 74], 4, 16),
            (1, 14, "writing", "medium", 50, (0..<50).map { 62 + Int(14 * sin(Double($0) / 7)) + $0 / 6 }, 3, 38),
            (2, 10, "studying", "deep", 45, (0..<45).map { 70 + Int(10 * sin(Double($0) / 9)) }, 5, -1),
            (4, 20, "reading", "light", 30, (0..<30).map { 55 + $0 / 2 }, 4, -1),
        ]
        let cal = Calendar.current
        for x in samples {
            let day = cal.date(byAdding: .day, value: -x.daysAgo, to: cal.startOfDay(for: .now))!
            let start = cal.date(bySettingHour: x.hour, minute: 5, second: 0, of: day)!
            let avg = x.curve.reduce(0, +) / x.curve.count
            let msg: [String: Any] = [
                "dur": x.min * 60 + 20, "avg": avg, "self": x.selfR, "tag": x.tag, "level": x.level,
                "start": Int(start.timeIntervalSince1970), "len": x.min, "peak": x.curve.max()!, "low": x.curve.min()!,
                "breaks": x.fade > 0 ? 1 : 0, "nudges": x.fade > 0 ? 1 : 0, "fade": x.fade,
                "hr": 64 + x.daysAgo, "hrmax": 96, "hrv": 44 + x.selfR, "curve": x.curve, "step": 60, "th": 70,
                "xp": x.min + (x.level == "deep" ? 10 : 0), "awards": x.daysAgo == 4 ? "First Focus" : "",
                "lat": 37.7793 + Double(x.daysAgo) * 0.0021, "lon": -122.4193 - Double(x.daysAgo) * 0.0017,
            ]
            if let r = Self.record(from: msg, session: nil) { history.append(r) }
        }
        saveHistory()
    }

    // MARK: Stats for gamification (spec §7)

    var weekRecords: [SessionRecord] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return history.filter { $0.date >= start }
    }

    var weekMinutes: Int { weekRecords.reduce(0) { $0 + $1.seconds } / 60 }
    /// Weekly focus-time goal shown on the Focus tab ring.
    let weeklyHoursGoal = 40
    var weeklyGoal: Int = UserDefaults.standard.object(forKey: "weeklyGoal") as? Int ?? 5 {
        didSet { UserDefaults.standard.set(weeklyGoal, forKey: "weeklyGoal") }
    }
    var totalXP: Int { history.reduce(0) { $0 + ($1.xp ?? 0) } }

    /// Focused minutes and mean score per day for the last 7 days (oldest first).
    var lastSevenDays: [(day: Date, minutes: Int, score: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let recs = history.filter { cal.isDate($0.date, inSameDayAs: day) }
            let mins = recs.reduce(0) { $0 + $1.seconds } / 60
            let score = recs.isEmpty ? 0 : recs.reduce(0) { $0 + $1.avgScore } / recs.count
            return (day, mins, score)
        }
    }

    /// Consecutive days with a session, ending today (or yesterday, so today isn't "broken" yet).
    var dayStreak: Int {
        let cal = Calendar.current
        let days = Set(history.map { cal.startOfDay(for: $0.date) })
        var day = cal.startOfDay(for: .now)
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while days.contains(day) {
            n += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    /// The block length the watch will suggest next (last planned length).
    var nextBlockMinutes: Int {
        let m = history.first?.plannedMinutes ?? 0
        return m > 0 ? m : 25
    }

    var weekMeanScore: Int {
        let r = weekRecords
        return r.isEmpty ? 0 : r.reduce(0) { $0 + $1.avgScore } / r.count
    }
    var totalHours: Double { Double(history.reduce(0) { $0 + $1.seconds }) / 3600 }

    // MARK: Persistence

    private static let historyURL = URL.documentsDirectory.appending(path: "history.json")
    private static let spotsURL = URL.documentsDirectory.appending(path: "shared-spots.json")

    private static func loadSpots() -> [SharedSpot] {
        guard let data = try? Data(contentsOf: spotsURL) else { return [] }
        return (try? JSONDecoder().decode([SharedSpot].self, from: data)) ?? []
    }

    private func saveSpots() {
        if let data = try? JSONEncoder().encode(sharedSpots) { try? data.write(to: Self.spotsURL, options: .atomic) }
    }

    private static func loadHistory() -> [SessionRecord] {
        guard let data = try? Data(contentsOf: historyURL) else { return [] }
        return (try? JSONDecoder().decode([SessionRecord].self, from: data)) ?? []
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(Array(history.prefix(500))) {
            try? data.write(to: Self.historyURL, options: .atomic)
        }
    }
}
