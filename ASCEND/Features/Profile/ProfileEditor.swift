import SwiftUI

struct ProfileEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProfileDraft
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    init(store: AppStore) {
        _draft = State(initialValue: ProfileDraft(store: store))
        _hasDeadline = State(initialValue: store.profile.targetDeadline != nil)
        _deadline = State(initialValue: store.profile.targetDeadline ?? store.policy.adding(days: 90, to: store.now))
    }
    var body: some View {
        Form {
            Section("Identity") { TextField("Name", text: $draft.name).textContentType(.givenName) }
            Section {
                OptionalNumericField(title: "Current weight · kg", value: $draft.currentWeight)
                OptionalNumericField(title: "Target weight · kg", value: $draft.targetWeight)
                NumericField(title: "Weekly pace · kg", value: $draft.weeklyChange)
                Toggle("Target deadline", isOn: $hasDeadline)
                if hasDeadline { DatePicker("Deadline", selection: $deadline, in: Date.now..., displayedComponents: .date) }
            } header: {
                Text("Body & goal")
            } footer: {
                Text("Changing your target begins a new goal baseline from your current weight. Historical measurements stay intact. Pace is a magnitude; goal direction comes from your target.")
            }
            Section("Daily targets") {
                NumericField(title: "Energy · kcal", value: $draft.calories)
                NumericField(title: "Protein · g", value: $draft.protein)
                NumericField(title: "Sleep · hours", value: $draft.sleepHours)
            }
        }.editor(title: "Profile & goals") {
            draft.deadline = hasDeadline ? deadline : nil
            if store.saveProfile(draft) { AppHaptics.success(enabled: store.settings.hapticsEnabled); dismiss() }
        }
    }
}
