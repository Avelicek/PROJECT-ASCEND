import SwiftUI

struct WeightEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kilograms: Double?
    @State private var date = Date.now
    var body: some View {
        Form {
            Section("Measurement") {
                OptionalNumericField(title: "Body weight · kg", value: $kilograms)
                DatePicker("Measured at", selection: $date, in: ...Date.now)
            }
            Section { Text("Daily entries are welcome. Even a weekly measurement helps build a useful trend.").font(.subheadline) }
            Section { HistoricalLogNote() }
        }.editor(title: "Log body weight") {
            guard let kilograms else { store.errorMessage = "Enter your body weight."; return }
            if store.logWeight(kilograms, at: date) { AppHaptics.success(enabled: store.settings.hapticsEnabled); dismiss() }
        }.onAppear { kilograms = store.progress.actualWeight }
    }
}
struct NutritionEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var date = Date.now
    var body: some View {
        Form {
            Section("Daily totals") {
                DatePicker("Day", selection: $date, in: ...Date.now, displayedComponents: .date)
                NumericField(title: "Calories · kcal", value: $calories, identifier: "nutrition.calories")
                NumericField(title: "Protein · g", value: $protein, identifier: "nutrition.protein")
            }
            Section { Text("Save replaces the daily total for the selected day. It does not add a meal.").font(.subheadline) }
            Section { HistoricalLogNote() }
        }.editor(title: "Log nutrition") {
            if store.logNutrition(calories: calories, protein: protein, on: date) { AppHaptics.success(enabled: store.settings.hapticsEnabled); dismiss() }
        }.onAppear { loadDay() }.onChange(of: date) { _, _ in loadDay() }
    }
    private func loadDay() {
        let entry = store.nutrition.first { $0.dayKey == store.policy.key(for: date) }
        calories = entry?.calories ?? 0; protein = entry?.proteinGrams ?? 0
    }
}
struct SleepEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var hours: Double = 8
    @State private var quality = 3
    @State private var date = Date.now
    @State private var includeTimes = false
    @State private var bedtime = Date.now.addingTimeInterval(-8 * 3600)
    @State private var wakeTime = Date.now
    var body: some View {
        Form {
            Section("Night's rest") {
                DatePicker("Day of waking", selection: $date, in: ...Date.now, displayedComponents: .date)
                NumericField(title: "Duration · hours", value: $hours).disabled(includeTimes)
                Picker("Sleep quality", selection: $quality) {
                    ForEach(1...5, id: \.self) { number in Text("\(number) / 5").tag(number) }
                }
                Toggle("Include bed and wake times", isOn: $includeTimes)
                if includeTimes {
                    DatePicker("Bedtime", selection: $bedtime, in: ...Date.now)
                    DatePicker("Wake time", selection: $wakeTime, in: ...Date.now)
                    Text("Duration is calculated from bed and wake times.").font(.caption).foregroundStyle(AppColor.muted)
                }
            }
            Section { HistoricalLogNote() }
        }.editor(title: "Log sleep") {
            if store.logSleep(hours: hours, quality: quality, on: date,
                              bedtime: includeTimes ? bedtime : nil, wakeTime: includeTimes ? wakeTime : nil) {
                AppHaptics.success(enabled: store.settings.hapticsEnabled); dismiss()
            }
        }.onAppear { loadDay() }.onChange(of: date) { _, _ in loadDay() }
    }
    private func loadDay() {
        let entry = store.sleep.first { $0.dayKey == store.policy.key(for: date) }
        hours = entry?.durationHours ?? store.profile.sleepTargetHours; quality = entry?.quality ?? 3
        includeTimes = entry?.bedtime != nil
        wakeTime = entry?.wakeTime ?? min(date, .now)
        bedtime = entry?.bedtime ?? wakeTime.addingTimeInterval(-hours * 3600)
    }
}
