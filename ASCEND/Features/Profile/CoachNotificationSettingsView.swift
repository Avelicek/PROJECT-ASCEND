import SwiftUI

struct CoachNotificationSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private var preferences: CoachPreferences { store.ownerSystem.coachPreferences ?? .init() }
    var body: some View {
        Form {
            Section("Morning rhythm") {
                DatePicker("Check-in time", selection: Binding(get: {
                    store.policy.calendar.date(bySettingHour: preferences.hour, minute: preferences.minute, second: 0, of: store.now) ?? store.now
                }, set: { date in
                    let components = store.policy.calendar.dateComponents([.hour, .minute], from: date)
                    edit { $0.hour = components.hour ?? 8; $0.minute = components.minute ?? 0 }
                }), displayedComponents: .hourAndMinute)
                Text("One morning reminder and one later follow-up. Completing check-in cancels today's reminders.").font(.caption).foregroundStyle(AppColor.muted)
            }
            Section("Categories") {
                ForEach(CoachNotificationCategory.allCases) { category in
                    Toggle(category.title, isOn: Binding(get: { preferences.enabled.contains(category) }, set: { enabled in
                        edit { if enabled { $0.enabled.insert(category) } else { $0.enabled.remove(category) } }
                    }))
                }
            }
            Section {
                Button("Enable notifications on this iPhone") { CoachNotifications.synchronize(store: store, requestPermission: true) }.frame(minHeight: 44)
                Text("Optional coaching reminders share a daily limit. Live Activity remains available when rest alerts are muted.").font(.caption).foregroundStyle(AppColor.muted)
            }
        }.navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    private func edit(_ change: (inout CoachPreferences) -> Void) {
        var value = preferences; change(&value)
        if store.saveOwnerSystem({ $0.coachPreferences = value }) {
            CoachNotifications.synchronize(store: store, requestPermission: false)
            if !value.enabled.contains(.rest) { RestNotifications.clear() }
        }
    }
}
