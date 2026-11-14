import Foundation
import UserNotifications

enum Notifier {
    static let unlockCategory = "focusbar.unlock"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Posted by the shield action extension: tapping it opens the app, which
    /// forwards the unlock request to the watch.
    static func postUnlockPrompt() {
        let content = UNMutableNotificationContent()
        content.title = "Earn it on your watch"
        content.body = "Tap to send the HR challenge to your watch."
        content.categoryIdentifier = unlockCategory
        content.sound = .default
        let request = UNNotificationRequest(identifier: "focusbar.unlock.prompt", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Reminder at the start of a #focus calendar event.
    static func scheduleFocusReminder(id: String, title: String, at date: Date) {
        guard date > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = "Focus time: \(title)"
        content.body = "Start a session on your watch."
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "focusbar.cal.\(id)", content: content, trigger: trigger))
    }

    static func post(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
