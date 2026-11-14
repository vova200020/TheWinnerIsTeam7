import FamilyControls
import Foundation
import ManagedSettings

// State shared between the app and its Screen Time extensions through the App Group.
// Extensions run in separate processes, so everything they need lives here.

enum AppGroup {
    static let id = "group.com.focusbar.companion"
    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }
}

struct UnlockGrant: Codable {
    var token: ApplicationToken
    var until: Date
}

struct PendingUnlock: Codable {
    var token: ApplicationToken
    var requestedAt: Date
    /// Screen Time tokens don't expose app names, so the watch shows a generic label.
    var appLabel: String { "blocked app" }
}

enum SharedStore {
    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            AppGroup.defaults.set(data, forKey: key)
        } else {
            AppGroup.defaults.removeObject(forKey: key)
        }
    }

    /// The running session, or nil.
    static var session: SessionState? {
        get { load("session") }
        set { save(newValue, "session") }
    }

    /// Apps/categories/sites blocked in Medium and Deep.
    static var blockSelection: FamilyActivitySelection {
        get { load("blockSelection") ?? FamilyActivitySelection() }
        set { save(newValue, "blockSelection") }
    }

    /// Always-allowed apps (emergency bypass: phone, maps, banking…). Never shielded.
    static var allowSelection: FamilyActivitySelection {
        get { load("allowSelection") ?? FamilyActivitySelection() }
        set { save(newValue, "allowSelection") }
    }

    /// Apps temporarily unlocked by an HR challenge on the watch.
    static var unlocks: [UnlockGrant] {
        get { load("unlocks") ?? [] }
        set { save(newValue, "unlocks") }
    }

    /// Set by the shield's "Unlock with watch" button; consumed by the app.
    static var pendingUnlock: PendingUnlock? {
        get { load("pendingUnlock") }
        set { save(newValue, "pendingUnlock") }
    }
}
