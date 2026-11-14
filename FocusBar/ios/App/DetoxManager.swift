import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import Observation

/// Screen Time side of the digital detox (spec §4, iOS column).
@MainActor
@Observable
final class DetoxManager {
    var authorized = AuthorizationCenter.shared.authorizationStatus == .approved
    var authError: String?

    var blockSelection = SharedStore.blockSelection {
        didSet { SharedStore.blockSelection = blockSelection; ShieldPolicy.apply() }
    }
    var allowSelection = SharedStore.allowSelection {
        didSet { SharedStore.allowSelection = allowSelection; ShieldPolicy.apply() }
    }

    var blockedCount: Int {
        blockSelection.applicationTokens.count + blockSelection.categoryTokens.count
            + blockSelection.webDomainTokens.count
    }
    var allowedCount: Int { allowSelection.applicationTokens.count }

    private let center = DeviceActivityCenter()

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = AuthorizationCenter.shared.authorizationStatus == .approved
            authError = nil
        } catch {
            authorized = false
            authError = "Screen Time access wasn't granted (\(error.localizedDescription)). "
                + "It needs a real iPhone; the simulator can't grant it."
        }
    }

    /// Session started on the watch → apply shields + a safety schedule that clears them
    /// 30 minutes after the planned end (4 h for open sessions) if session_end never arrives.
    func begin(_ session: SessionState) {
        SharedStore.session = session
        SharedStore.unlocks = []
        ShieldPolicy.apply()
        let safety = (session.plannedMinutes > 0 ? session.plannedMinutes : 210) + 30
        try? center.startMonitoring(.focusSession, during: ShieldPolicy.schedule(from: .now, minutes: safety))
    }

    func end() {
        SharedStore.session = nil
        SharedStore.unlocks = []
        SharedStore.pendingUnlock = nil
        center.stopMonitoring([.focusSession, .unlockWindow])
        ShieldPolicy.clearAll()
    }

    /// unlock_granted from the watch: lift the shield for `minutes`, then the monitor
    /// extension re-locks (15-min schedule whose warning fires at the `minutes` mark).
    func grantUnlock(minutes: Int) -> Bool {
        guard let pending = SharedStore.pendingUnlock else { return false }
        let until = Date.now.addingTimeInterval(TimeInterval(minutes * 60 - 5))
        var unlocks = SharedStore.unlocks
        unlocks.append(UnlockGrant(token: pending.token, until: until))
        SharedStore.unlocks = unlocks
        SharedStore.pendingUnlock = nil
        ShieldPolicy.apply()
        try? center.startMonitoring(.unlockWindow,
                                    during: ShieldPolicy.schedule(from: .now, minutes: 15, warnAfter: minutes))
        return true
    }

    /// Re-check on foreground in case the extension didn't run.
    func refresh() {
        ShieldPolicy.apply()
    }
}
