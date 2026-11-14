import ManagedSettings
import UserNotifications

/// Handles the shield's buttons. Extensions can't talk to the watch, so the
/// request is parked in the App Group and a notification opens the app,
/// which forwards `unlock_request` to the watch (spec §5.1 step 2).
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            SharedStore.pendingUnlock = PendingUnlock(token: application, requestedAt: .now)
            Notifier.postUnlockPrompt()
            completionHandler(.defer)   // keep the shield; it re-evaluates once unlocked
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)   // websites stay blocked for the whole session
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
}
