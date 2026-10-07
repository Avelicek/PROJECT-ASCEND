import SwiftUI
import Charts

struct ExerciseRoute: Identifiable { let id: String }
enum ExerciseIdentity {
    static func tracking(_ mode: TrackingMode) -> String {
        switch mode { case .reps: "REPS · OPTIONAL ADDED LOAD"; case .weightAndReps: "LOAD / REPS"; case .duration: "DURATION"; case .distance: "DISTANCE / TIME" }
    }
    static func tint(_ exercise: TrainingExercise?) -> Color {
        guard let exercise else { return AppColor.secondary }
        return exercise.bodyweight ? AppColor.recovery : exercise.required.contains(.dumbbells) ? AppColor.blue : AppColor.strength
    }
    static func performance(_ value: SetPerformance, mode: TrackingMode, bodyweight: Bool) -> String {
        switch mode {
        case .reps: return value.kilograms > 0 ? "\(value.reps) reps · +\(value.kilograms.formatted()) kg" : "\(value.reps) reps"
        case .weightAndReps:
            if bodyweight { return value.kilograms > 0 ? "BW + \(value.kilograms.formatted()) kg × \(value.reps)" : "\(value.reps) reps" }
            return "\(value.kilograms.formatted()) kg × \(value.reps)"
        case .duration: return "\(Int(value.seconds)) sec"
        case .distance: return "\(value.distanceMeters.formatted()) m · \(Int(value.seconds)) sec"
        }
    }
}

struct ExerciseLibraryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ExerciseQuery()
    @State private var detail: ExerciseRoute?
    var onSelect: ((Exercise) -> Void)? = nil
    var replacing: String? = nil
    var allowUnavailableSelection = false
    private var recommendations: [SubstitutionSuggestion] {
        guard let replacing, let source = store.trainingMetadata(replacing) else { return [] }
        if store.brainArchive.settings.enabled, let minimum = PersonalBrainEngine().readiness(source, context: store.personalContext).minimum, minimum < 55 {
            return PersonalBrainEngine().recoveryReplacements(for: source, context: store.personalContext).map {
                SubstitutionSuggestion(exercise: $0, score: 100, reason: "Different focus · recorded recovery supports this available movement. Your choice; no automatic replacement.")
            }
        }
        return TrainingSystem().substitutes(for: source, catalog: TrainingCatalog.definitions, state: store.training)
    }
    private var entries: [Exercise] { store.library(query) }
    var body: some View {
        let entries = self.entries
        let recommendations = self.recommendations
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                TextField("Find an exercise", text: $query.search).padding(14).background(AppColor.elevated, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("library.search").autocorrectionDisabled()
                filters
                if replacing != nil && query.search.isEmpty {
                    Eyebrow(text: "EQUIPMENT-COMPATIBLE REPLACEMENTS")
                    if recommendations.isEmpty { Text("No available substitute. Update My Gym or keep this exercise.").font(.caption).foregroundStyle(AppColor.muted) }
                    ForEach(recommendations.prefix(5), id: \.exercise.id) { suggestion in
                        if let exercise = store.exercises.first(where: { $0.catalogID == suggestion.exercise.id }) {
                            libraryRow(exercise, reason: suggestion.reason)
                        }
                    }
                    Eyebrow(text: "FULL LIBRARY")
                }
                HStack { Eyebrow(text: "\(entries.count) EXERCISES"); Spacer(); Text("My Gym controls availability").font(.caption2).foregroundStyle(AppColor.muted) }
                if entries.isEmpty { EmptyStateCard(symbol: "magnifyingglass", title: "No matching exercises.", detail: "Try fewer filters or include unavailable equipment.") }
                ForEach(entries, id: \.catalogID) { exercise in libraryRow(exercise) }
            }.padding(20)
        }.accessibilityIdentifier("screen.exerciselibrary").background(AppColor.background)
            .navigationTitle(replacing == nil ? "Exercise library" : "Replace exercise").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $detail) { route in NavigationStack { ExerciseHistoryView(exerciseID: route.id).environment(store) }.preferredColorScheme(.dark) }
            .onAppear {
                if replacing != nil { query.availableOnly = true }
                if onSelect != nil, let draft = store.activeWorkout,
                   let selected = draft.exercises.first(where: { $0.id == draft.selectedExerciseID }) ?? draft.exercises.last {
                    query.preferredFocus = store.trainingMetadata(selected.catalogID)?.focus
                }
            }
    }
    private var filters: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    filterChip("Available", selected: $query.availableOnly)
                    filterChip("Bodyweight", selected: $query.bodyweightOnly)
                    filterChip("Favorites", selected: $query.favoritesOnly)
                    filterChip("Include hidden", selected: $query.showHidden)
                }
            }
            HStack {
                Menu {
                    Button("All muscles") { query.focus = nil }
                    ForEach(TrainingFocus.allCases, id: \.self) { value in Button(value.title) { query.focus = value } }
                } label: { Label(query.focus?.title ?? "Muscle", systemImage: "figure.strengthtraining.traditional") }
                Menu {
                    Button("All equipment") { query.equipment = nil }
                    ForEach(GymEquipment.allCases) { value in Button(value.title) { query.equipment = value } }
                } label: { Text(query.equipment?.title ?? "Equipment") }
                Spacer(minLength: 0)
                Menu {
                    ForEach(ExerciseSort.allCases, id: \.self) { value in Button(value.rawValue.capitalized) { query.sort = value } }
                } label: { Image(systemName: "arrow.up.arrow.down") }.accessibilityLabel("Sort exercises")
            }.font(.caption).foregroundStyle(AppColor.secondary).frame(minHeight: 44)
        }
    }
    private func filterChip(_ title: String, selected: Binding<Bool>) -> some View {
        Button { selected.wrappedValue.toggle() } label: { Text(title).font(.caption.weight(.medium)).padding(.horizontal, 12).frame(minHeight: 44).background(selected.wrappedValue ? AppColor.recovery.opacity(0.17) : AppColor.surface, in: Capsule()).foregroundStyle(selected.wrappedValue ? AppColor.recovery : AppColor.muted) }
            .accessibilityValue(selected.wrappedValue ? "Selected" : "Not selected")
    }
    private func libraryRow(_ exercise: Exercise, reason: String? = nil) -> some View {
        let metadata = store.trainingMetadata(exercise.catalogID)
        let missing = store.missingEquipment(exercise.catalogID)
        let tint = ExerciseIdentity.tint(metadata)
        let duplicate = store.activeWorkout?.exercises.contains { $0.catalogID == exercise.catalogID } ?? false
        return HStack(spacing: 6) {
            Button {
                if let onSelect { onSelect(exercise); dismiss() }
                else { detail = .init(id: exercise.catalogID) }
            } label: {
                PremiumCard(role: .metric, tint: tint) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text(exercise.name).font(.headline).foregroundStyle(AppColor.text); Spacer(); if store.training.favorites.contains(exercise.catalogID) { Image(systemName: "star.fill").foregroundStyle(AppColor.gold).font(.caption) } }
                        Text(metadata.map { "\($0.focus.title) · \($0.pattern.title)" } ?? exercise.primaryMuscleNames.joined(separator: " · ")).font(.caption).foregroundStyle(tint)
                        Text(metadata?.required.map(\.title).sorted().joined(separator: " · ") ?? exercise.equipmentRaw.capitalized).font(.caption2).foregroundStyle(AppColor.muted)
                        HStack {
                            Text(exercise.trackingMode == .reps && !exercise.additionalWeightAllowed ? "REPS" : ExerciseIdentity.tracking(exercise.trackingMode)).font(.system(size: 9, weight: .medium)).foregroundStyle(tint)
                            Spacer()
                            Text(missing.isEmpty ? "AVAILABLE" : "UNAVAILABLE").font(.system(size: 9, weight: .medium)).foregroundStyle(missing.isEmpty ? AppColor.positive : AppColor.warning)
                        }
                        if let reason { Text(reason).font(.caption2).foregroundStyle(AppColor.muted) }
                        if onSelect != nil && !missing.isEmpty { Text("Missing: " + missing.map(\.title).sorted().joined(separator: ", ")).font(.caption2).foregroundStyle(AppColor.warning) }
                    }
                }
            }.buttonStyle(PremiumPressStyle()).accessibilityIdentifier("live.choose.\(exercise.catalogID)")
                .disabled(onSelect != nil && ((!allowUnavailableSelection && !missing.isEmpty) || (replacing != nil && duplicate)))
            if onSelect == nil {
                Menu {
                    Button(store.training.favorites.contains(exercise.catalogID) ? "Remove favorite" : "Favorite", systemImage: "star") { store.toggleFavorite(exercise.catalogID) }
                    Button(store.training.hidden.contains(exercise.catalogID) ? "Unhide" : "Hide", systemImage: "eye.slash") { store.toggleHidden(exercise.catalogID) }
                } label: { Image(systemName: "ellipsis").foregroundStyle(AppColor.muted).frame(width: 44, height: 44) }.accessibilityLabel("Exercise preferences")
            }
        }
    }
}

struct ExerciseHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let exerciseID: String
    private var exercise: Exercise? { store.exercises.first { $0.catalogID == exerciseID } }
    private var history: [ExerciseHistory] { store.exerciseHistory.filter { $0.exerciseID == exerciseID && $0.date <= store.now && !$0.working.isEmpty }.sorted { $0.date > $1.date } }
    private var metadata: TrainingExercise? { store.trainingMetadata(exerciseID) }
    private var tint: Color { ExerciseIdentity.tint(metadata) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FeatureHeader(eyebrow: metadata?.pattern.title.uppercased() ?? "EXERCISE", title: exercise?.name ?? exerciseID)
                HStack {
                    Button(store.training.favorites.contains(exerciseID) ? "Favorited" : "Favorite", systemImage: "star") { store.toggleFavorite(exerciseID) }.accessibilityIdentifier("exercise.favorite")
                    Spacer()
                    Button(store.training.hidden.contains(exerciseID) ? "Unhide" : "Hide", systemImage: "eye.slash") { store.toggleHidden(exerciseID) }.accessibilityIdentifier("exercise.hide")
                }.font(.caption).tint(tint).frame(minHeight: 44)
                PremiumCard(role: .metric, tint: tint) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(metadata?.required.map(\.title).sorted().joined(separator: " · ") ?? "Personal exercise").font(.caption).foregroundStyle(tint)
                        Text(store.missingEquipment(exerciseID).isEmpty ? "Available in My Gym" : "Missing: " + store.missingEquipment(exerciseID).map(\.title).sorted().joined(separator: ", ")).font(.caption).foregroundStyle(AppColor.muted)
                        Text(exercise?.contributions.filter { $0.fraction >= 0.1 }.map { $0.muscle.title }.joined(separator: " · ") ?? "").font(.caption2).foregroundStyle(AppColor.muted)
                        if let last = history.first, let value = last.working.first?.performance {
                            Eyebrow(text: "LAST PERFORMANCE")
                            Text(describe(value, mode: last.mode)).font(.title3.weight(.semibold)).foregroundStyle(tint)
                        }
                        if let best = bestPerformance {
                            Eyebrow(text: bestTitle)
                            Text(best).font(.headline).foregroundStyle(AppColor.gold)
                        }
                        Text("\(history.filter { $0.date >= store.now.addingTimeInterval(-28 * 86400) }.count) sessions in the last 28 days").font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
                if history.isEmpty { EmptyStateCard(symbol: "chart.xyaxis.line", title: "Your baseline starts here.", detail: "Completed sessions will appear here. Choose this exercise in a workout or routine.") }
                else {
                    if exercise?.trackingMode == .reps || exercise?.trackingMode == .weightAndReps { trend }
                    Eyebrow(text: "RECENT SESSIONS")
                    ForEach(Array(history.prefix(12).enumerated()), id: \.offset) { _, session in
                        PremiumCard(role: .analytics, tint: tint) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { Text(session.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(AppColor.muted); Spacer(); if session.quick { PillStatus(title: "QUICK") } }
                                Text(session.working.map { describe($0.performance, mode: session.mode) }.joined(separator: "  /  ")).font(.subheadline).foregroundStyle(AppColor.secondary)
                            }
                        }
                    }
                }
                if let metadata, let variation = TrainingSystem().harderVariation(for: metadata, history: history, state: store.training, now: store.now) {
                    PremiumCard(role: .status, tint: AppColor.recovery) { Text("Three consistent sessions above 20 reps. Consider \(variation.name.lowercased()) when technique feels ready.").font(.caption) }
                }
                let records = store.records.filter { $0.exerciseCatalogID == exerciseID }
                if !records.isEmpty {
                    Eyebrow(text: "PERSONAL BESTS")
                    ForEach(records.prefix(12), id: \.id) { record in
                        HStack(alignment: .top) { Image(systemName: "trophy.fill"); VStack(alignment: .leading, spacing: 4) { Text(RecordPresentation.title(record.kindRaw, bodyweight: exercise?.bodyweightCapable ?? false)); Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(AppColor.muted) }; Spacer(); Text("\(record.value.formatted()) \(RecordPresentation.unit(record.kindRaw))").monospacedDigit() }.font(.caption).foregroundStyle(AppColor.gold)
                    }
                }
            }.padding(20)
        }.accessibilityIdentifier("screen.exercisehistory").background(AppColor.background).navigationTitle("Exercise history").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    private func describe(_ value: SetPerformance, mode: TrackingMode) -> String { ExerciseIdentity.performance(value, mode: mode, bodyweight: exercise?.bodyweightCapable ?? false) }
    private var bestTitle: String {
        guard let exercise else { return "BEST PERFORMANCE" }
        if exercise.trackingMode == .duration { return "LONGEST WORKING SET" }
        if exercise.trackingMode == .distance { return "LONGEST DISTANCE" }
        return exercise.bodyweightCapable || exercise.trackingMode == .reps ? "BEST REPS AT LAST ADDED LOAD" : "BEST ESTIMATED STRENGTH"
    }
    private var bestPerformance: String? {
        guard let exercise else { return nil }
        let sets = history.filter { !$0.quick && $0.mode == exercise.trackingMode }.flatMap(\.working).map(\.performance)
        if exercise.trackingMode == .duration { return sets.max { $0.seconds < $1.seconds }.map { describe($0, mode: .duration) } }
        if exercise.trackingMode == .distance { return sets.max { $0.distanceMeters < $1.distanceMeters }.map { describe($0, mode: .distance) } }
        if exercise.bodyweightCapable || exercise.trackingMode == .reps {
            let lastLoad = history.first?.working.first?.performance.kilograms ?? 0
            return sets.filter { abs($0.kilograms - lastLoad) < 0.001 }.max { $0.reps < $1.reps }.map { describe($0, mode: exercise.trackingMode) }
        }
        if exercise.trackingMode == .weightAndReps { return WorkoutEngine().recordCandidates(sets).first { $0.kind == .estimatedOneRepMax }.map { "\($0.value.formatted(.number.precision(.fractionLength(1)))) kg · estimated 1RM" } }
        return nil
    }
    private var trend: some View {
        let bodyweight = (exercise?.bodyweightCapable ?? false) || exercise?.trackingMode == .reps
        let points = Array(history.filter { !$0.quick && ($0.mode == .reps || $0.mode == .weightAndReps) }.prefix(20).reversed())
        return PremiumCard(role: .analytics, tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: bodyweight ? "REPS · EACH ADDED LOAD KEPT SEPARATE" : "BEST LOAD PER SESSION")
                Chart {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, session in
                        if bodyweight {
                            ForEach(Array(Set(session.working.map { $0.performance.kilograms })).sorted(), id: \.self) { kg in
                                let reps = session.working.filter { $0.performance.kilograms == kg }.map { $0.performance.reps }.max() ?? 0
                                LineMark(x: .value("Date", session.date), y: .value("Reps", reps), series: .value("Added load", kg)).foregroundStyle(tint)
                                PointMark(x: .value("Date", session.date), y: .value("Reps", reps)).foregroundStyle(tint)
                            }
                        } else { LineMark(x: .value("Date", session.date), y: .value("Load", session.working.map { $0.performance.kilograms }.max() ?? 0)).foregroundStyle(tint) }
                    }
                }.chartYScale(domain: .automatic(includesZero: false)).frame(height: 145)
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                    .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
                    .accessibilityLabel(bodyweight ? "Best recorded reps, added loads kept separate" : "Best recorded load per full session")
            }
        }
    }
}
