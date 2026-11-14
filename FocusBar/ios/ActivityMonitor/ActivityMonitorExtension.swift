import DeviceActivity
import Foundation
import ManagedSettings

/// Runs even when the app is closed. Re-locks apps when an unlock window ends,
/// and clears all shields if a session outlives its safety window (e.g. the watch
/// died and never sent session_end) — the phone must never stay locked by accident.
class ActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        ShieldPolicy.apply()
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        if activity == .unlockWindow {
            ShieldPolicy.apply()   // the 5-minute grant has expired → shield again
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == .focusSession {
            SharedStore.session = nil
            SharedStore.unlocks = []
        }
        ShieldPolicy.apply()
    }
}
