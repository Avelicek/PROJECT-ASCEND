import SwiftUI

private struct SetDraft: Identifiable {
    let id = UUID()
    var reps: Double = 8
    var weight: Double = 0
    var minutes: Double = 1
    var kilometers: Double = 1
}
struct WorkoutEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selection = ""
    @State private var quick = true
    @State private var sets = [SetDraft()]
    @State private var date = Date.now
    @State private var exertion: Double = 7
    private var exercise: Exercise? { store.exercises.first { $0.catalogID == selection } }
    var body: some View {
        Form {
            Section("Training") {
                Picker("Exercise", selection: $selection) {
                    Text("Choose exercise").tag("")
                    ForEach(store.exercises, id: \.catalogID) { exercise in Text(exercise.name).tag(exercise.catalogID) }
                }
                Picker("Logging style", selection: $quick) { Text("Quick log").tag(true); Text("Full log").tag(false) }.pickerStyle(.segmented)
                DatePicker("Performed at", selection: $date, in: ...Date.now)
            }
            if let exercise {
                Section {
                    Text("\(exercise.equipmentRaw.capitalized) · \(exercise.contributions.map { $0.muscle.group }.uniqued().joined(separator: ", "))")
                        .font(.caption).foregroundStyle(AppColor.muted)
                    if let previous = store.sessions.flatMap(\.exercises).first(where: { $0.exercise?.catalogID == exercise.catalogID }) {
                        Text("Previous: \(previousSummary(previous))").font(.caption)
                    }
                }
                ForEach($sets) { $set in
                    Section(quick ? "Total" : "Working set \((sets.firstIndex { $0.id == set.id } ?? 0) + 1)") {
                        if exercise.trackingMode == .reps || exercise.trackingMode == .weightAndReps { NumericField(title: "Reps", value: $set.reps) }
                        if exercise.trackingMode == .weightAndReps || exercise.additionalWeightAllowed {
                            NumericField(title: exercise.bodyweightCapable ? "Additional weight · kg" : "Weight · kg", value: $set.weight)
                        }
                        if exercise.trackingMode == .duration || exercise.trackingMode == .distance { NumericField(title: "Duration · minutes", value: $set.minutes) }
                        if exercise.trackingMode == .distance { NumericField(title: "Distance · km", value: $set.kilometers) }
                    }
                }.onDelete { indices in if !quick && sets.count - indices.count > 0 { sets.remove(atOffsets: indices) } }
                if !quick { Button("Add set", systemImage: "plus") { if sets.count < 30 { sets.append(sets.last.map { SetDraft(reps: $0.reps, weight: $0.weight, minutes: $0.minutes, kilometers: $0.kilometers) } ?? SetDraft()) } } }
                Section("Effort") {
                    HStack { Text("Perceived exertion"); Spacer(); Text("\(Int(exertion)) / 10") }
                    Slider(value: $exertion, in: 1...10, step: 1).accessibilityLabel("Perceived exertion")
                }
            }
            Section { HistoricalLogNote() }
        }.editor(title: "Log workout") {
            guard let exercise else { store.errorMessage = "Choose an exercise first."; return }
            guard sets.allSatisfy({ $0.reps.isFinite && (0...2000).contains($0.reps) && $0.reps.rounded() == $0.reps }) else {
                store.errorMessage = "Reps must be whole numbers from 0 to 2000."; return
            }
            guard sets.allSatisfy({ $0.weight.isFinite && $0.weight >= 0 && $0.minutes.isFinite && $0.minutes >= 0 && $0.kilometers.isFinite && $0.kilometers >= 0 }) else {
                store.errorMessage = "Weight, duration and distance must be valid positive values."; return
            }
            let performances = sets.map { set in
                SetPerformance(reps: exercise.trackingMode == .duration || exercise.trackingMode == .distance ? 0 : Int(set.reps),
                    kilograms: exercise.trackingMode == .weightAndReps || exercise.additionalWeightAllowed ? set.weight : 0,
                    seconds: exercise.trackingMode == .duration || exercise.trackingMode == .distance ? set.minutes * 60 : 0,
                    distanceMeters: exercise.trackingMode == .distance ? set.kilometers * 1000 : 0)
            }
            if store.logWorkout(exercise: exercise, sets: performances, at: date, quick: quick, exertion: exertion) {
                AppHaptics.success(enabled: store.settings.hapticsEnabled); dismiss()
            }
        }.onChange(of: quick) { _, value in if value { sets = [sets.first ?? SetDraft()] } }
            .onChange(of: selection) { _, _ in sets = [SetDraft()] }
    }
    private func previousSummary(_ entry: WorkoutExercise) -> String {
        entry.sets.sorted { $0.order < $1.order }.map { set in
            switch entry.trackingMode {
            case .reps: "\(set.reps) reps" + (set.weightKG > 0 ? " · +\(set.weightKG.formatted()) kg" : "")
            case .weightAndReps: "\(set.weightKG.formatted()) kg × \(set.reps)"
            case .duration: "\((set.durationSeconds / 60).formatted()) min"
            case .distance: "\((set.distanceMeters / 1000).formatted()) km"
            }
        }.joined(separator: " · ")
    }
}
private extension Array where Element: Hashable { func uniqued() -> [Element] { Array(Set(self)).sorted { String(describing: $0) < String(describing: $1) } } }
