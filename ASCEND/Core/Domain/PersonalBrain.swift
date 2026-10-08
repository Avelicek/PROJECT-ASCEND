import Foundation

public enum RecommendationAction: String, Codable, Sendable { case train, trainLight, recover, maintain
    public var title: String { switch self { case .train: "Ready to train"; case .trainLight: "Train light"; case .recover: "Recover"; case .maintain: "Active recovery" } }
}
public enum BrainIntensity: String, Codable, Sendable { case normal, progressIfReady, holdLoad, light, recoverySession
    public var title: String { switch self { case .normal: "Normal"; case .progressIfReady: "Progress if ready"; case .holdLoad: "Hold load"; case .light: "Light"; case .recoverySession: "Recovery session" } }
}
public enum BrainDuration: Int, Codable, CaseIterable, Sendable { case flexible = 0, short = 30, standard = 45, long = 60
    public var title: String { self == .flexible ? "Flexible" : "\(rawValue) min" }
}
public struct BrainSettings: Codable, Sendable {
    public var enabled = true
    public var useSleep = true
    public var useNutrition = true
    public var duration: BrainDuration = .flexible
    public init() {}
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        useSleep = try values.decodeIfPresent(Bool.self, forKey: .useSleep) ?? true
        useNutrition = try values.decodeIfPresent(Bool.self, forKey: .useNutrition) ?? true
        duration = try values.decodeIfPresent(BrainDuration.self, forKey: .duration) ?? .flexible
    }
}
public enum PreferenceSignal: String, Codable, Sendable { case accepted, rejected, ignored, routineStarted, substitutionAccepted, substitutionRejected, exerciseChosen, exerciseSkipped
    public var weight: Double { switch self { case .accepted, .routineStarted: 2; case .rejected: -2; case .ignored: -0.5; case .substitutionAccepted, .exerciseChosen: 1; case .substitutionRejected, .exerciseSkipped: -1 } }
}
public struct BrainHistoryEntry: Codable, Sendable, Identifiable {
    public let id: String
    public let date: Date
    public let action: RecommendationAction
    public let focus: String
    public let routineID: UUID?
    public let exerciseIDs: [String]
    public let confidence: Confidence
    public var response: PreferenceSignal?
    public var respondedAt: Date?
}
public struct BrainPreference: Codable, Sendable {
    public let date: Date
    public let key: String
    public let signal: PreferenceSignal
    public init(date: Date, key: String, signal: PreferenceSignal) { self.date = date; self.key = key; self.signal = signal }
}
public struct BrainArchive: Codable, Sendable {
    public var version = 1
    public var settings = BrainSettings()
    public var history: [BrainHistoryEntry] = []
    public var preferences: [BrainPreference] = []
    public init() {}
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        settings = try values.decodeIfPresent(BrainSettings.self, forKey: .settings) ?? .init()
        history = try values.decodeIfPresent([BrainHistoryEntry].self, forKey: .history) ?? []
        preferences = try values.decodeIfPresent([BrainPreference].self, forKey: .preferences) ?? []
    }
    public mutating func record(_ decision: BrainDecision, date: Date) {
        guard !history.contains(where: { $0.id == decision.id }) else { return }
        history.append(.init(id: decision.id, date: date, action: decision.action, focus: decision.focus,
            routineID: decision.routineID, exerciseIDs: decision.session?.exercises.map(\.exerciseID) ?? [], confidence: decision.confidence))
        history = Array(history.suffix(180))
    }
    public mutating func respond(id: String, signal: PreferenceSignal, date: Date) {
        guard let index = history.firstIndex(where: { $0.id == id }), history[index].response == nil else { return }
        history[index].response = signal; history[index].respondedAt = date
        if let routine = history[index].routineID { preferences.append(.init(date: date, key: routine.uuidString, signal: signal)) }
        preferences = Array(preferences.suffix(300))
    }
}
public struct PersonalContext: Sendable {
    public var date: Date
    public var dayKey = ""
    public var sickMode = false
    public var sleepMode = false
    public var activeWorkout = false
    public var currentELO = 0
    public var rank = "Unranked"
    public var weight: Double?
    public var targetWeight: Double?
    public var weightMomentum: Double?
    public var sleepHours: Double?
    public var sleepQuality: Int?
    public var sleepConfidence: Confidence = .low
    public var sleepTarget = 8.0
    public var calories: Double?
    public var calorieGoal = 0.0
    public var protein: Double?
    public var proteinGoal = 0.0
    public var calorieAdherence: Double?
    public var proteinAdherence: Double?
    public var nutritionDays = 0
    public var history: [ExerciseHistory] = []
    public var sessionDates: [Date] = []
    public var trainingDays = 0
    public var daysSinceLastSession: Int?
    public var recovery: ReadinessReport = .init(percent: nil, state: nil, muscles: [], confidence: .low)
    public var weeklyMuscles: [String: Double] = [:]
    public var weeklyMovements: [MovementPattern: Int] = [:]
    public var progression: [BrainOpportunity] = []
    public var training = PersonalTrainingState()
    public var archive = BrainArchive()
    public init(date: Date) { self.date = date }
}
public struct BrainOpportunity: Sendable, Identifiable {
    public let exerciseID: String
    public let name: String
    public let previous: SetPerformance?
    public let suggestion: ProgressionSuggestion
    public let plateau: Bool
    public let improved: Bool
    public var recordWindow = false
    public var id: String { exerciseID }
}
public struct BrainMusclePriority: Sendable, Identifiable {
    public let name: String
    public let recovery: Double?
    public var id: String { name }
}
public struct BrainDecision: Sendable {
    public let id: String
    public let action: RecommendationAction
    public let focus: String
    public let routineID: UUID?
    public let session: WorkoutRoutine?
    public let duration: Int?
    public let confidence: Confidence
    public let intensity: BrainIntensity
    public let reasons: [String]
    public let warnings: [String]
    public let missing: [String]
    public let muscles: [BrainMusclePriority]
    public let opportunities: [BrainOpportunity]
    public var facts: [String] { [action.title, "Focus: \(focus)", "Intensity: \(intensity.title)"] + warnings + reasons }
}

public struct PersonalBrainEngine: Sendable {
    public init() {}
    // Significant load allocation is a conservative heuristic, never measured activation.
    public func readiness(_ exercise: TrainingExercise, context: PersonalContext) -> (minimum: Double?, known: Bool) {
        let relevant = exercise.muscles.filter { $0.fraction >= 0.08 }
        let observed = relevant.compactMap { part in context.recovery.muscles.first { $0.muscle == part.muscle && $0.lastTrainedAt != nil } }
        return (observed.map(\.recoveryPercent).min(), !relevant.isEmpty && observed.count == relevant.count)
    }
    public func plateau(_ history: [ExerciseHistory], exercise: LiveExercise, date: Date) -> Bool {
        let recent = Array(ProgressionEngine().comparable(history, exercise: exercise, now: date).prefix(4))
        guard recent.count == 4, Set(recent.map(\.sessionID)).count == 4, recent.allSatisfy({ $0.working.count >= 2 }),
              let anchor = recent.first?.working.first?.performance else { return false }
        // Compare the best set at a shared load, excluding warmups and quick logs.
        let best = recent.compactMap { $0.working.filter { abs($0.performance.kilograms - anchor.kilograms) < 0.001 }.map { $0.performance.reps }.max() }
        return best.count == 4 && Set(best).count == 1 && recent.allSatisfy { entry in
            entry.working.contains { ($0.rpe ?? 0) >= 8 }
        }
    }
    public func preference(_ key: String, context: PersonalContext) -> Double {
        let signals = context.archive.preferences.filter { $0.key == key && $0.date <= context.date && $0.date >= context.date.addingTimeInterval(-90 * 86400) }
        return FitnessMath.clamp(signals.suffix(12).reduce(0) { $0 + $1.signal.weight }, -6...6)
    }
    public func progressionFacts(_ context: PersonalContext, catalog: [TrainingExercise] = TrainingCatalog.definitions) -> [BrainOpportunity] {
        let ids = Set(context.history.filter { !$0.quick && $0.date <= context.date && $0.date >= context.date.addingTimeInterval(-42 * 86400) }.map(\.exerciseID))
        let settings = context.archive.settings
        let supported = context.sessionDates.count >= 3 && context.recovery.confidence != .low &&
            (!settings.useSleep || context.sleepHours != nil) && (!settings.useNutrition || context.nutritionDays >= 2)
        let sleepLimited = settings.useSleep && ((context.sleepHours.map { $0 < 6 } ?? false) || (context.sleepQuality.map { $0 <= 2 } ?? false))
        let fuelLimited = settings.useNutrition && ((context.proteinAdherence.map { $0 < 0.7 } ?? false) || (context.calorieAdherence.map { $0 < 0.75 } ?? false))
        return catalog.filter { ids.contains($0.id) && TrainingSystem().missing($0, profile: context.training.profile).isEmpty && !context.training.hidden.contains($0.id) }.map { exercise in
            let live = LiveExercise(catalogID: exercise.id, name: exercise.name, mode: exercise.mode, bodyweight: exercise.bodyweight,
                addedWeight: exercise.additional, weightStep: exercise.required.contains(.dumbbells) ? 1 : 2.5, contributions: exercise.muscles)
            let recovery = readiness(exercise, context: context)
            let suggestion = ProgressionEngine().suggest(context.history, exercise: live, now: context.date,
                recoveryLimited: !supported || !recovery.known || (recovery.minimum ?? 0) < 70 || sleepLimited || fuelLimited || context.trainingDays >= 5)
            let recent = ProgressionEngine().comparable(context.history, exercise: live, now: context.date)
            return .init(exerciseID: exercise.id, name: exercise.name, previous: recent.first?.working.first?.performance, suggestion: suggestion,
                plateau: plateau(context.history, exercise: live, date: context.date), improved: recent.first.map { ProgressionEngine().progressed(current: $0, prior: context.history) } ?? false)
        }
    }
    public func decide(_ context: PersonalContext, catalog: [TrainingExercise] = TrainingCatalog.definitions) -> BrainDecision {
        let settings = context.archive.settings
        if settings.enabled && (context.sickMode || context.sleepMode || context.activeWorkout) {
            let focus = context.sickMode ? "Recovery protection" : context.sleepMode ? "Sleep" : "Active session"
            return BrainDecision(id: context.dayKey + ":mode:" + focus, action: context.activeWorkout && !context.sickMode && !context.sleepMode ? .maintain : .recover, focus: focus, routineID: nil, session: nil, duration: nil, confidence: context.recovery.confidence, intensity: .recoverySession,
                reasons: [context.sickMode ? "User-declared Sick Mode: training pressure paused. Fuel and sleep remain active." : context.sleepMode ? "A recorded sleep interval is in progress." : "Resume the active workout before starting another session."], warnings: [], missing: [], muscles: [], opportunities: [])
        }
        let history = context.history.filter { $0.date <= context.date && !$0.quick }
        let poorSleep = settings.useSleep && ((context.sleepHours.map { $0 < 6 } ?? false) || (context.sleepQuality.map { $0 <= 2 } ?? false))
        let poorFuel = settings.useNutrition && ((context.proteinAdherence.map { $0 < 0.7 } ?? false) || (context.calorieAdherence.map { $0 < 0.75 } ?? false))
        var missing: [String] = []
        let recentSessions = context.sessionDates.filter { $0 <= context.date && $0 >= context.date.addingTimeInterval(-42 * 86400) }
        if recentSessions.count < 3 { missing.append("More recent completed training exposures") }
        if settings.useSleep && context.sleepHours == nil { missing.append("Recent sleep") }
        if settings.useNutrition && context.nutritionDays < 2 { missing.append("Recent nutrition") }
        if context.recovery.confidence == .low { missing.append("Supported recovery history") }
        var confidence: Confidence = missing.isEmpty ? (context.recovery.confidence == .high ? .high : .medium) : .low
        let available = catalog.filter { TrainingSystem().missing($0, profile: context.training.profile).isEmpty && !context.training.hidden.contains($0.id) }
        let progression = context.progression.isEmpty ? progressionFacts(context, catalog: available) : context.progression
        let targetMinutes = settings.duration == .flexible ? context.training.profile.sessionMinutes : settings.duration.rawValue
        func estimate(_ routine: WorkoutRoutine) -> Int { max(10, 5 + routine.exercises.reduce(0) { $0 + 2 + $1.sets * (45 + $1.restSeconds) / 60 }) }
        func score(_ entries: [TrainingExercise], key: String) -> Double {
            let values = entries.map { readiness($0, context: context) }
            let minimum = values.compactMap { $0.minimum }.min() ?? 60
            guard minimum >= 55 else { return -1000 }
            let known = values.allSatisfy { $0.known }
            let exposure = FitnessMath.average(entries.map { Double(context.weeklyMovements[$0.pattern, default: 0]) }) ?? 0
            let muscleExposure = FitnessMath.average(entries.flatMap(\.muscles).map { context.weeklyMuscles[$0.muscle.group, default: 0] }) ?? 0
            let favorites = Double(entries.filter { context.training.favorites.contains($0.id) }.count)
            let familiar = min(2, Double(entries.filter { entry in history.contains { $0.exerciseID == entry.id } }.count))
            let strengthFit = context.training.profile.goal == .strength ? min(2, Double(entries.filter { [.horizontalPull, .verticalPull, .horizontalPush, .squat, .hinge].contains($0.pattern) }.count)) : 0
            let progressionFit = min(2, Double(entries.filter { entry in progression.contains { $0.exerciseID == entry.id && $0.suggestion.target != nil } }.count))
            let exercisePreferences = FitnessMath.clamp(entries.reduce(0.0) { $0 + preference($1.id, context: context) } / Double(max(1, entries.count)), -2...2)
            return minimum + (known ? 15 : -25) - min(5, exposure * 0.3 + muscleExposure * 0.1) + min(3, favorites) + familiar + strengthFit + progressionFit + FitnessMath.clamp(preference(key, context: context) + exercisePreferences, -6...6)
        }
        let compatible = context.training.routines.filter { routine in
            routine.isValid && routine.exercises.allSatisfy { item in available.contains { $0.id == item.exerciseID } }
        }
        let ordered = compatible.sorted { a, b in
            func value(_ routine: WorkoutRoutine) -> Double {
                let entries = routine.exercises.compactMap { item in available.first { $0.id == item.exerciseID } }
                return score(entries, key: routine.id.uuidString) - min(12, Double(max(0, estimate(routine) - targetMinutes)) * 0.5)
            }
            let left = value(a), right = value(b)
            return left == right ? (a.name == b.name ? a.id.uuidString < b.id.uuidString : a.name < b.name) : left > right
        }
        var chosen = ordered.first.flatMap { routine -> WorkoutRoutine? in
            let entries = routine.exercises.compactMap { item in available.first { $0.id == item.exerciseID } }
            return score(entries, key: routine.id.uuidString) > -900 ? routine : nil
        }
        var savedID = chosen?.id
        if chosen == nil {
            let candidates = available.filter { [.horizontalPush, .horizontalPull, .verticalPull, .squat, .hinge, .lunge, .coreStability, .elbowFlexion].contains($0.pattern) }.sorted {
                let a = score([$0], key: $0.id), b = score([$1], key: $1.id)
                return a == b ? $0.id < $1.id : a > b
            }
            var patterns = Set<MovementPattern>(), families = Set<String>()
            var entries: [RoutineExercise] = []
            for exercise in candidates where score([exercise], key: exercise.id) > -900 {
                let family = exercise.family ?? exercise.id
                guard !patterns.contains(exercise.pattern), !families.contains(family) else { continue }
                patterns.insert(exercise.pattern); families.insert(family)
                var item = RoutineExercise(exercise.id, sets: context.training.profile.goal == .generalFitness ? 2 : 3)
                item.id = Self.stableID(exercise.id)
                entries.append(item)
                if entries.count >= min(5, max(2, targetMinutes / 10)) { break }
            }
            if entries.count >= 2 {
                var generated = WorkoutRoutine(name: "Suggested session", exercises: entries)
                generated.id = Self.stableID(entries.map(\.exerciseID).joined(separator: ":")); chosen = generated; savedID = nil
            }
        }
        var action: RecommendationAction = .train
        var intensity: BrainIntensity = .normal
        var warnings: [String] = [], reasons: [String] = []
        let entries = chosen?.exercises.compactMap { item in available.first { $0.id == item.exerciseID } } ?? []
        let allKnown = !entries.isEmpty && entries.allSatisfy { readiness($0, context: context).known }
        let knownMinimum = entries.compactMap { readiness($0, context: context).minimum }.min()
        if !entries.isEmpty && !allKnown { missing.append("Muscle history for part of this session"); confidence = .low }
        let highEffort = history.filter { entry in entry.date >= context.date.addingTimeInterval(-3 * 86400) && entries.contains(where: { $0.id == entry.exerciseID }) }
            .flatMap(\.working).compactMap(\.rpe).filter { $0 >= 9 }.count >= 3
        if !settings.enabled { action = .maintain; reasons = ["Personal Brain is paused in settings."]; chosen = nil; savedID = nil }
        else if chosen == nil || (settings.useSleep && (context.sleepHours.map { $0 < 4 } ?? false)) {
            action = .recover; intensity = .recoverySession; warnings.append("No suitable training session within today's recorded limits."); chosen = nil; savedID = nil
        } else if context.daysSinceLastSession == 0 {
            action = .maintain; intensity = .recoverySession; reasons.append("A completed training session is already recorded today."); chosen = nil; savedID = nil
        } else if poorSleep || context.trainingDays >= 5 || !allKnown || (knownMinimum.map { $0 < 70 } ?? false) {
            action = .trainLight; intensity = .light
            if !allKnown { reasons.append("Some muscle history is unknown. Establish a familiar, easy baseline.") }
            if context.trainingDays >= 5 { warnings.append("Five or more training days this week; keep today's work light.") }
        } else if poorFuel || highEffort { intensity = .holdLoad }
        if poorSleep { warnings.append("Recent sleep duration or quality is low; reduce intensity.") }
        if highEffort { warnings.append("Several recent working sets reported near-maximum effort. Hold rather than increase.") }
        if let momentum = context.weightMomentum, momentum < 0, context.weight != nil, context.targetWeight != nil {
            reasons.append("Your observed weight trend is moving away from your target; review intake consistency.")
        }
        if poorFuel {
            let phrases = ["Recent fuel coverage is low; hold familiar loads.", "Nutrition has been below goal. Defer aggressive progression."]
            let day = Int(context.date.timeIntervalSince1970 / 86400)
            warnings.append(phrases[abs(day % phrases.count)])
        }
        var opportunities: [BrainOpportunity] = []
        for exercise in entries {
            let live = LiveExercise(catalogID: exercise.id, name: exercise.name, mode: exercise.mode, bodyweight: exercise.bodyweight,
                addedWeight: exercise.additional, weightStep: exercise.required.contains(.dumbbells) ? 1 : 2.5, contributions: exercise.muscles)
            let comparable = ProgressionEngine().comparable(history, exercise: live, now: context.date)
            let limited = action != .train || poorFuel || highEffort || confidence == .low
            let suggestion = ProgressionEngine().suggest(history, exercise: live, now: context.date, recoveryLimited: limited)
            var opportunity = BrainOpportunity(exerciseID: exercise.id, name: exercise.name, previous: comparable.first?.working.first?.performance,
                suggestion: suggestion, plateau: plateau(history, exercise: live, date: context.date),
                improved: comparable.first.map { ProgressionEngine().progressed(current: $0, prior: history) } ?? false)
            if let target = suggestion.target {
                let prior = history.filter { $0.exerciseID == exercise.id && $0.mode == exercise.mode }.flatMap(\.working).map(\.performance)
                let bestReps = prior.filter { abs($0.kilograms - target.kilograms) < 0.001 }.map(\.reps).max()
                opportunity.recordWindow = bestReps.map { target.reps > $0 } ?? (target.kilograms > (prior.map(\.kilograms).max() ?? target.kilograms))
            }
            opportunities.append(opportunity)
        }
        opportunities.sort { a, b in
            func priority(_ entry: BrainOpportunity) -> Int { entry.suggestion.target != nil ? 3 : entry.plateau ? 2 : entry.improved ? 1 : 0 }
            return priority(a) == priority(b) ? a.exerciseID < b.exerciseID : priority(a) > priority(b)
        }
        if action == .train && !poorFuel && !highEffort && opportunities.contains(where: { $0.suggestion.target != nil }) { intensity = .progressIfReady }
        let groups = ["Back", "Biceps", "Chest", "Legs", "Shoulders", "Core", "Glutes", "Triceps", "Calves"]
        let muscles = groups.map { group -> BrainMusclePriority in
            let observed = context.recovery.muscles.filter { entry in
                let belongs = group == "Biceps" ? [.bicepsLongHead, .bicepsShortHead, .brachialis].contains(entry.muscle) :
                    group == "Triceps" ? [.tricepsLongHead, .tricepsLateralHead, .tricepsMedialHead].contains(entry.muscle) : entry.muscle.group == group
                return belongs && entry.lastTrainedAt != nil
            }
            return .init(name: group, recovery: observed.map(\.recoveryPercent).min())
        }
        if let chosen {
            reasons.append(savedID == nil ? "A small session built from your available equipment." : "\(chosen.name) matches your equipment and current recorded recovery.")
            if allKnown, let knownMinimum { reasons.append("Lowest relevant muscle estimate: \(Int(knownMinimum.rounded()))% recovery.") }
            if let days = context.daysSinceLastSession { reasons.append("Last completed session: \(days) day\(days == 1 ? "" : "s") ago.") }
            if let low = entries.min(by: { context.weeklyMovements[$0.pattern, default: 0] < context.weeklyMovements[$1.pattern, default: 0] }) {
                reasons.append("\(low.pattern.title) exposure this week: \(context.weeklyMovements[low.pattern, default: 0]) working sets. Balance is a secondary signal.")
            }
        }
        if reasons.isEmpty { reasons = ["Keep gentle activity comfortable and log missing inputs for stronger guidance."] }
        let patterns = Set(entries.map(\.pattern))
        let focus: String
        if chosen == nil { focus = action == .recover ? "Recovery" : "Maintain" }
        else if patterns.isSubset(of: [.horizontalPull, .verticalPull, .elbowFlexion, .shoulderIsolation]) { focus = "Pull" }
        else if patterns.isSubset(of: [.horizontalPush, .verticalPush, .elbowExtension, .coreStability]) { focus = "Push" }
        else if entries.allSatisfy({ [.quads, .hamstrings, .glutes, .calves].contains($0.focus) }) { focus = "Legs" }
        else { focus = savedID == nil ? "Full body" : chosen?.name ?? "Training" }
        let id = [context.dayKey.isEmpty ? String(Int(context.date.timeIntervalSince1970 / 86400)) : context.dayKey,
            action.rawValue, intensity.rawValue, confidence.rawValue, savedID?.uuidString ?? "generated", chosen?.exercises.map(\.exerciseID).joined(separator: ",") ?? "none"].joined(separator: ":")
        return .init(id: id, action: action, focus: focus, routineID: savedID, session: chosen, duration: chosen.map(estimate), confidence: confidence,
            intensity: intensity, reasons: reasons, warnings: warnings, missing: missing, muscles: muscles, opportunities: opportunities)
    }
    public static func stableID(_ text: String) -> UUID {
        var hash: UInt64 = 14695981039346656037
        for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        let hex = String(format: "%016llx", hash)
        return UUID(uuidString: "00000000-0000-0000-\(hex.prefix(4))-\(hex.suffix(12))") ?? UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))
    }
    public func recoveryReplacements(for source: TrainingExercise, context: PersonalContext, catalog: [TrainingExercise] = TrainingCatalog.definitions) -> [TrainingExercise] {
        guard let minimum = readiness(source, context: context).minimum, minimum < 55 else { return [] }
        return catalog.filter { entry in
            let value = readiness(entry, context: context)
            return entry.id != source.id && entry.focus != source.focus && !context.training.hidden.contains(entry.id) &&
                TrainingSystem().missing(entry, profile: context.training.profile).isEmpty && value.known && (value.minimum ?? 0) >= 70
        }.sorted { a, b in
            let favoriteA = context.training.favorites.contains(a.id), favoriteB = context.training.favorites.contains(b.id)
            if favoriteA != favoriteB { return favoriteA }
            return a.id < b.id
        }
    }
    public func sessionRead(_ summary: CompletedWorkoutSummary) -> [String] {
        var facts = ["\(summary.workingSets) working sets · \(summary.progressedExercises) exercises progressed."]
        if let record = summary.records.first { facts.append("\(record.exerciseName): \(record.title) improved.") }
        if let muscle = summary.muscles.first { facts.append("\(muscle.name) received the most recorded session load. Recheck recovery before loading it again.") }
        return Array(facts.prefix(3))
    }
    public func dayRead(_ result: DailyResult, calories: Double? = nil, protein: Double? = nil,
                        calorieGoal: Double? = nil, proteinGoal: Double? = nil, trained: Bool? = nil, loadedMuscle: String? = nil) -> [String] {
        var facts: [String] = []
        if let trained { facts.append(trained ? "Training recorded." : "No completed training recorded.") }
        if let calories, let calorieGoal { facts.append("Energy: \(Int(calories.rounded())) / \(Int(calorieGoal.rounded())) kcal recorded.") }
        if let protein, let proteinGoal { facts.append("Protein: \(Int(protein.rounded())) / \(Int(proteinGoal.rounded())) g recorded.") }
        if facts.isEmpty { facts = result.elo.components.prefix(2).map { "\($0.label): \($0.points > 0 ? "+" : "")\($0.points) ELO." } }
        facts.append("Total: \(result.elo.delta > 0 ? "+" : "")\(result.elo.delta) ELO.")
        if let loadedMuscle { facts.append("Recorded \(loadedMuscle.lowercased()) load merits a recovery check before repeating that focus.") }
        return facts
    }
}
