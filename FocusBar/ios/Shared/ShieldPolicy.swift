import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

extension ManagedSettingsStore.Name {
    static let focusBar = Self("focusbar")
}

extension DeviceActivityName {
    /// Safety net: clears shields if the watch never sends session_end.
    static let focusSession = Self("focusbar.session")
    /// Re-locks an app after an HR unlock window.
    static let unlockWindow = Self("focusbar.unlock")
}

/// One function computes the shields from shared state, so the app and the
/// DeviceActivity monitor extension always agree.
enum ShieldPolicy {
    static func apply(now: Date = .now) {
        let store = ManagedSettingsStore(named: .focusBar)
        guard let session = SharedStore.session, session.level != .light else {
            store.clearAllSettings()
            return
        }

        // Drop expired unlocks, keep the live ones out of the shield.
        let live = SharedStore.unlocks.filter { $0.until > now }
        if live.count != SharedStore.unlocks.count { SharedStore.unlocks = live }
        let unlocked = Set(live.map(\.token))

        let block = SharedStore.blockSelection
        let allow = SharedStore.allowSelection
        let exempt = allow.applicationTokens.union(unlocked)

        switch session.level {
        case .light:
            store.clearAllSettings()
        case .medium:
            let apps = block.applicationTokens.subtracting(exempt)
            store.shield.applications = apps.isEmpty ? nil : apps
            store.shield.applicationCategories = block.categoryTokens.isEmpty
                ? nil : .specific(block.categoryTokens, except: exempt)
            store.shield.webDomains = block.webDomainTokens.isEmpty ? nil : block.webDomainTokens
            store.shield.webDomainCategories = block.categoryTokens.isEmpty
                ? nil : .specific(block.categoryTokens, except: allow.webDomainTokens)
        case .deep:
            // Allow-list only (spec §3.2 "Deep"): every category is shielded except exempt apps.
            let apps = block.applicationTokens.subtracting(exempt)
            store.shield.applications = apps.isEmpty ? nil : apps
            store.shield.applicationCategories = .all(except: exempt)
            store.shield.webDomainCategories = .all(except: allow.webDomainTokens)
        }
    }

    static func clearAll() {
        ManagedSettingsStore(named: .focusBar).clearAllSettings()
    }

    /// DeviceActivity schedules must be ≥ 15 minutes, so a 5-minute unlock is a
    /// 15-minute interval whose *warning* fires 10 minutes early, at the 5-minute mark.
    static func schedule(from start: Date, minutes: Int, warnAfter: Int? = nil) -> DeviceActivitySchedule {
        let cal = Calendar.current
        let comps: Set<Calendar.Component> = [.era, .year, .month, .day, .hour, .minute, .second]
        let length = max(minutes, 15)
        let end = start.addingTimeInterval(TimeInterval(length * 60))
        var warning: DateComponents?
        if let warnAfter, warnAfter < length {
            warning = DateComponents(minute: length - warnAfter)
        }
        return DeviceActivitySchedule(
            intervalStart: cal.dateComponents(comps, from: start),
            intervalEnd: cal.dateComponents(comps, from: end),
            repeats: false,
            warningTime: warning
        )
    }
}
