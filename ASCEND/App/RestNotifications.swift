import Foundation
import UserNotifications

@MainActor enum RestNotifications {
    static let identifier = "ascend.rest.completed"
    static func cancel() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier]) }
    static func synchronize(_ rest: RestClock?, enabled: Bool) {
        clear()
        guard enabled, let rest, !rest.finishAcknowledged, let deadline = rest.deadline, deadline > .now else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            var allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            if settings.authorizationStatus == .notDetermined { allowed = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false }
            guard allowed, deadline > .now else { return }
            // An older asynchronous permission response must not schedule a skipped/replaced rest.
            guard rest.deadline == currentDeadline else { return }
            let content = UNMutableNotificationContent(); content.title = "Rest complete"; content.body = "Your next set is ready when you are."; content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false)))
        }
        currentDeadline = deadline
    }
    private static var currentDeadline: Date?
    static func clear() { currentDeadline = nil; cancel() }
}
