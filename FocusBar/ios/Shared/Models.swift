import Foundation

// Shared by the full (Screen Time) and Lite targets.

/// Detox levels from spec §3.2 / §4. iOS can't toggle Focus/DND programmatically,
/// so "light" is advisory; medium/deep are enforced with Screen Time shields.
enum DetoxLevel: String, Codable, CaseIterable, Identifiable {
    case light, medium, deep
    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Light"
        case .medium: "Medium"
        case .deep: "Deep"
        }
    }

    var detail: String {
        switch self {
        case .light: "Do Not Disturb (you turn it on)"
        case .medium: "Block your distracting apps"
        case .deep: "Block everything except your allow-list"
        }
    }

    init(watchName: String?) {
        self = DetoxLevel(rawValue: watchName ?? "") ?? .light
    }
}

struct SessionState: Codable, Equatable {
    var tag: String
    var level: DetoxLevel
    var startedAt: Date
    var plannedMinutes: Int   // 0 = open-ended
}
