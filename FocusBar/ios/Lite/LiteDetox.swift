import Foundation
import Observation

// Lite build (free Apple ID): no Screen Time, so blocking is simulated inside the app.
// Everything else — watch messages, unlock challenge, calendar — is real.
// These types mirror the full build's SharedStore / DetoxManager API used by AppModel.

struct PendingUnlock: Codable {
    var app: String
    var requestedAt: Date
    /// "com.focusbar.feed" → the watch shows "Earn feed".
    var appLabel: String { "com.\(app.lowercased()).app" }
}

enum SharedStore {
    private static let defaults = UserDefaults.standard

    static var session: SessionState? {
        get { defaults.data(forKey: "lite.session").flatMap { try? JSONDecoder().decode(SessionState.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "lite.session") }
    }

    static var pendingUnlock: PendingUnlock?
}

/// A pretend app on the demo phone screen.
struct MockApp: Identifiable, Hashable {
    let id: String
    let symbol: String
    let distracting: Bool
    let essential: Bool   // "Always allowed": never blocked (spec §5.2 emergency bypass)

    static let all: [MockApp] = [
        MockApp(id: "Feed", symbol: "camera.fill", distracting: true, essential: false),
        MockApp(id: "Shorts", symbol: "play.rectangle.fill", distracting: true, essential: false),
        MockApp(id: "Chat", symbol: "bubble.left.and.bubble.right.fill", distracting: true, essential: false),
        MockApp(id: "Games", symbol: "gamecontroller.fill", distracting: true, essential: false),
        MockApp(id: "News", symbol: "newspaper.fill", distracting: false, essential: false),
        MockApp(id: "Mail", symbol: "envelope.fill", distracting: false, essential: false),
        MockApp(id: "Phone", symbol: "phone.fill", distracting: false, essential: true),
        MockApp(id: "Maps", symbol: "map.fill", distracting: false, essential: true),
        MockApp(id: "Bank", symbol: "building.columns.fill", distracting: false, essential: true),
    ]
}

@MainActor
@Observable
final class DetoxManager {
    private(set) var level: DetoxLevel?
    private(set) var unlockedUntil: [String: Date] = [:]
    /// The app whose shield is waiting on the watch, if any.
    private(set) var waitingFor: String?

    func isLocked(_ app: MockApp, now: Date = .now) -> Bool {
        guard let level, level != .light, !app.essential else { return false }
        if let until = unlockedUntil[app.id], until > now { return false }
        return level == .deep || app.distracting
    }

    func begin(_ session: SessionState) {
        SharedStore.session = session
        level = session.level
        unlockedUntil = [:]
    }

    func end() {
        SharedStore.session = nil
        SharedStore.pendingUnlock = nil
        level = nil
        unlockedUntil = [:]
        waitingFor = nil
    }

    /// Shield's "Unlock with watch".
    func requestUnlock(_ app: MockApp) {
        SharedStore.pendingUnlock = PendingUnlock(app: app.id, requestedAt: .now)
        waitingFor = app.id
    }

    func cancelUnlock() {
        SharedStore.pendingUnlock = nil
        waitingFor = nil
    }

    /// unlock_granted from the watch.
    func grantUnlock(minutes: Int) -> Bool {
        guard let pending = SharedStore.pendingUnlock else { return false }
        unlockedUntil[pending.app] = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        SharedStore.pendingUnlock = nil
        waitingFor = nil
        return true
    }

    func refresh() {
        level = SharedStore.session?.level
    }
}
