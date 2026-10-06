import SwiftUI

struct ObjectiveManager: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var editing: DailyObjective?
    var body: some View {
        List {
            Section {
                ForEach(store.objectives.filter(\.isActive), id: \.id) { objective in
                    Button { editing = objective } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(objective.title).foregroundStyle(AppColor.text)
                            Text("\(objective.cadenceRaw.capitalized) · \(objective.importanceRaw.capitalized) · \(objective.target.formatted()) \(objective.unit)")
                                .font(.caption).foregroundStyle(AppColor.muted)
                        }
                    }.swipeActions { Button("Archive", role: .destructive) { _ = store.archiveObjective(objective) } }
                }
                Button("Add objective", systemImage: "plus") { adding = true }
            } footer: { Text("Weekly objectives are due on the weekday of their start date. Edits affect today and future occurrences; closed-day snapshots stay intact.") }
            Section("Recovery alternatives") {
                ForEach(store.todayObjectives.filter { $0.kindRaw == ObjectiveKind.exercise.rawValue || $0.kindRaw == ObjectiveKind.workout.rawValue }, id: \.occurrenceKey) { occurrence in
                    Button(occurrence.recoveryExempt ? "Protected · \(occurrence.title)" : "Choose recovery day for \(occurrence.title)") {
                        _ = store.chooseRecoveryAlternative(occurrence)
                    }.disabled(occurrence.recoveryExempt || occurrence.completedAt != nil)
                }
            } footer: { Text("If training is inappropriate today, explicitly choose recovery. This occurrence is exempt from a missed-objective penalty. Automated suggestions will be added after personal recovery confidence improves.") }
        }.scrollContentBackground(.hidden).background(AppColor.background)
            .navigationTitle("Your objectives").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $adding) { NavigationStack { ObjectiveEditor().environment(store) } }
            .sheet(item: $editing) { objective in NavigationStack { ObjectiveEditor(existing: objective).environment(store) } }
    }
}
struct ObjectiveEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let existing: DailyObjective?
    @State private var draft: ObjectiveDraft
    init(existing: DailyObjective? = nil) {
        self.existing = existing
        var value = ObjectiveDraft()
        if let existing {
            value.title = existing.title; value.kind = existing.kind; value.cadence = ObjectiveCadence(rawValue: existing.cadenceRaw) ?? .daily
            value.importance = existing.importance; value.target = existing.target; value.unit = existing.unit
            value.startsAt = existing.startsAt; value.weekdays = existing.weekdays; value.exerciseCatalogID = existing.exerciseCatalogID
        }
        _draft = State(initialValue: value)
    }
    var body: some View {
        Form {
            Section("Objective") {
                TextField("Title", text: $draft.title)
                Picker("Metric", selection: $draft.kind) {
                    ForEach(ObjectiveKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                if draft.kind == .exercise {
                    Picker("Exercise", selection: $draft.exerciseCatalogID) {
                        Text("Choose exercise").tag(String?.none)
                        ForEach(store.exercises.filter { $0.trackingMode == .reps || $0.trackingMode == .weightAndReps }, id: \.catalogID) {
                            Text($0.name).tag(Optional($0.catalogID))
                        }
                    }
                }
                if draft.kind != .bodyWeight && draft.kind != .workout {
                    NumericField(title: "Target", value: $draft.target)
                    if draft.kind == .custom { TextField("Unit", text: $draft.unit) }
                }
                Picker("Importance", selection: $draft.importance) {
                    ForEach(ObjectiveImportance.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
            }
            Section("Schedule") {
                Picker("Repeat", selection: $draft.cadence) {
                    ForEach(ObjectiveCadence.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                DatePicker("Starts", selection: $draft.startsAt, displayedComponents: .date)
                if draft.cadence == .weekdays {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(store.policy.calendar.weekdaySymbols[day - 1], isOn: Binding(get: { draft.weekdays.contains(day) }, set: { selected in
                            draft.weekdays.removeAll { $0 == day }; if selected { draft.weekdays.append(day) }
                        }))
                    }
                }
            }
        }.editor(title: existing == nil ? "New objective" : "Edit objective") {
            if store.saveObjective(draft, editing: existing) { AppHaptics.success(enabled: store.settings.hapticsEnabled); dismiss() }
        }.onChange(of: draft.kind) { _, kind in
            switch kind {
            case .calories: draft.target = store.profile.calorieGoal; draft.unit = "kcal"
            case .protein: draft.target = store.profile.proteinGoal; draft.unit = "g"
            case .bodyWeight: draft.target = 1; draft.unit = "entry"
            case .workout: draft.target = 1; draft.unit = "session"
            case .exercise: draft.target = 50; draft.unit = "reps"
            case .custom: draft.target = 1; draft.unit = "times"
            }
        }
    }
}
