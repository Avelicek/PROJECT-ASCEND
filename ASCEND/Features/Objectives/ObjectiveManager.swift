import SwiftUI

private struct ObjectiveEditRoute: Identifiable { let objective: DailyObjective; var id: UUID { objective.id } }

struct ObjectiveManager: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var editing: ObjectiveEditRoute?
    @State private var activity: DailyObjectiveCompletion?
    @State private var metric: LogDestination?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FeatureHeader(eyebrow: "DAILY SYSTEM", title: "Your rhythm")
                Text("Real activity drives exercise objectives. Protected training stays visibly paused.").font(.caption).foregroundStyle(AppColor.muted)
                ForEach(store.todayObjectives, id: \.occurrenceKey) { occurrence in
                    ObjectiveRow(occurrence: occurrence) {
                        switch ObjectiveKind(rawValue: occurrence.kindRaw) {
                        case .exercise, .count, .duration: activity = occurrence
                        case .custom: _ = store.toggleObjective(occurrence)
                        case .calories, .protein: metric = .nutrition
                        case .bodyWeight: metric = .weight
                        case .sleep: metric = .sleep
                        case .workout:
                            if occurrence.recoveryExempt { activity = occurrence } else { dismiss(); store.navigationRequest = .workout }
                        case nil: break
                        }
                    }
                }
                if !store.suggestedObjectives.isEmpty {
                    DisclosureGroup("Coach suggestions for today") {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(store.suggestedObjectives) { suggestion in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(suggestion.draft.title).font(.subheadline.weight(.medium))
                                    Text(suggestion.reason).font(.caption).foregroundStyle(AppColor.muted)
                                    Button("Add for today") { _ = store.saveObjective(suggestion.draft) }.frame(minHeight: 44)
                                }
                            }
                            Text("Suggestions are optional and never replace your existing objectives.").font(.caption).foregroundStyle(AppColor.muted)
                        }.padding(.top, 12)
                    }.font(.subheadline).accessibilityIdentifier("coach.objective.suggestions")
                }
                PrimaryAction(title: "Add objective", symbol: "plus", tint: AppColor.blue) { adding = true }.accessibilityIdentifier("objective.add")
                SectionHeader(title: "Recurring rules")
                ForEach(store.objectives.filter(\.isActive), id: \.id) { objective in
                    PremiumCard(role: .inline) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(objective.title).font(.subheadline.weight(.medium))
                            Text("\(objective.cadenceRaw.capitalized) · \(objective.target.formatted()) \(objective.unit)").font(.caption).foregroundStyle(AppColor.muted)
                            HStack { Button("Edit") { editing = .init(objective: objective) }; Spacer(); Button("Archive", role: .destructive) { _ = store.archiveObjective(objective) } }.font(.caption).frame(minHeight: 44)
                        }
                    }
                }
                Text("Edits affect today and future occurrences. Archiving preserves today; closed-day snapshots and ELO stay intact.").font(.caption2).foregroundStyle(AppColor.muted)
            }.padding(20)
        }.featureBackground().accessibilityIdentifier("screen.objectives").toolbar(.visible, for: .navigationBar).navigationTitle("Objectives").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $metric) { destination in
                NavigationStack {
                    switch destination {
                    case .nutrition: NutritionEditor().environment(store)
                    case .weight: WeightEditor().environment(store)
                    case .sleep: SleepEditor().environment(store)
                    default: EmptyView()
                    }
                }
            }
            .sheet(isPresented: $adding) { NavigationStack { ObjectiveEditor().environment(store) } }
            .sheet(item: $editing) { objective in NavigationStack { ObjectiveEditor(existing: objective.objective).environment(store) } }
            .sheet(item: $activity) { occurrence in NavigationStack { ObjectiveActivityView(occurrence: occurrence).environment(store) } }
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
                        ForEach(store.exercises.filter { $0.trackingMode != .distance }, id: \.catalogID) {
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
        }.onChange(of: draft.exerciseCatalogID) { _, id in
            draft.unit = store.exercises.first(where: { $0.catalogID == id })?.trackingMode == .duration ? "seconds" : "reps"
        }.onChange(of: draft.kind) { _, kind in
            switch kind {
            case .calories: draft.target = store.profile.calorieGoal; draft.unit = "kcal"
            case .protein: draft.target = store.profile.proteinGoal; draft.unit = "g"
            case .bodyWeight: draft.target = 1; draft.unit = "entry"
            case .workout: draft.target = 1; draft.unit = "session"
            case .exercise: draft.target = 50; draft.unit = "reps"
            case .custom: draft.target = 1; draft.unit = "times"
            case .sleep: draft.target = store.profile.sleepTargetHours; draft.unit = "hours"
            case .count: draft.target = 10; draft.unit = "count"
            case .duration: draft.target = 60; draft.unit = "seconds"
            }
        }
    }
}
