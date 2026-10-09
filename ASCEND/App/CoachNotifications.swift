import Foundation
import Observation
import UserNotifications
import UIKit

@MainActor @Observable final class CoachNotificationRouter {
    static let shared = CoachNotificationRouter()
    var route: String?
}
final class AscendNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self; return true
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let route = response.notification.request.content.userInfo["ascendRoute"] as? String ?? "workout"
        await MainActor.run { CoachNotificationRouter.shared.route = route }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
}

@MainActor enum CoachNotifications {
    private static var task: Task<Void, Never>?
    static func synchronize(store: AppStore, requestPermission: Bool) {
        guard !store.isDemo, !AppMotion.snapshotMode, !store.container.configurations.allSatisfy(\.isStoredInMemoryOnly) else { return }
        let preferences = store.ownerSystem.coachPreferences ?? .init()
        let policy = store.policy, now = store.actionDate(), checked = store.checkInToday != nil
        let action = store.nextBestAction, score = store.projectedScore.delta, projection = store.goalProjection
        task?.cancel()
        task = Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            guard !Task.isCancelled else { return }
            center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("ascend.coach.") }.map(\.identifier))
            let status = await center.notificationSettings()
            var allowed = status.authorizationStatus == .authorized || status.authorizationStatus == .provisional
            if requestPermission && status.authorizationStatus == .notDetermined { allowed = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false }
            guard allowed, !Task.isCancelled else { return }
            func schedule(id: String, title: String, body: String, route: String, at date: Date) async {
                guard date > now, !Task.isCancelled else { return }
                let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
                content.userInfo = ["ascendRoute": route]
                var components = policy.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                components.timeZone = policy.calendar.timeZone
                do { try await center.add(.init(identifier: "ascend.coach." + id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))) }
                catch { store.errorMessage = "Reminder could not be scheduled: \(error.localizedDescription)" }
            }
            if preferences.enabled.contains(.morning) {
                for offset in 0..<7 where offset != 0 || !checked {
                    let day = policy.adding(days: offset, to: now)
                    guard let morning = policy.calendar.date(bySettingHour: preferences.hour, minute: preferences.minute, second: 0, of: day) else { continue }
                    await schedule(id: policy.key(for: day) + ".morning", title: "Good morning. Time to check in.", body: "Record weight and sleep to adjust today's plan.", route: "checkIn", at: morning)
                    // One follow-up only. A completed check-in cancels both requests for today.
                    let later = min(morning.addingTimeInterval(3 * 3600), policy.adding(days: 1, to: policy.start(of: day)).addingTimeInterval(-3600))
                    if later > morning { await schedule(id: policy.key(for: day) + ".followup", title: "Your check-in is still open", body: "A quick weight and sleep update will help today's plan.", route: "checkIn", at: later) }
                }
            }
            // At most one optional contextual evening notification, with real current facts.
            let category: CoachNotificationCategory
            switch action.action { case .nutrition: category = .nutrition; case .workout, .resume: category = .workout; case .recovery: category = .recovery; case .objectives: category = .objectives; default: category = .intervention }
            if preferences.enabled.contains(category), let evening = policy.calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) {
                await schedule(id: policy.key(for: now) + ".action", title: action.title, body: action.reason, route: action.action.rawValue, at: evening)
            } else if preferences.enabled.contains(.goal), let weeks = projection.weeks, let evening = policy.calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) {
                await schedule(id: policy.key(for: now) + ".goal", title: "Your goal trend", body: "Estimated \(weeks.lowerBound)–\(weeks.upperBound) weeks · \(projection.confidence.rawValue) confidence.", route: "progress", at: evening)
            }
            if preferences.enabled.contains(.weekly) {
                let offset = (1 - policy.calendar.component(.weekday, from: now) + 7) % 7
                if let sunday = policy.calendar.date(bySettingHour: 19, minute: 0, second: 0, of: policy.adding(days: offset, to: now)) {
                    await schedule(id: "weekly", title: "Your weekly coach report", body: "Review your recorded training, trend and plan adjustments. Today's projected ELO: \(score).", route: "weekly", at: sunday)
                }
            }
        }
    }
}
