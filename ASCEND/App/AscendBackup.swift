import Foundation
import SwiftData
import CryptoKit

struct AscendBackupEnvelope: Codable, Sendable {
    var schemaVersion = 1
    var exportedAt: Date
    var appVersion: String
    var payload: BackupPayload
    var payloadSHA256: String
    init(payload: BackupPayload, date: Date) throws {
        self.payload = payload; exportedAt = date
        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        payloadSHA256 = try Self.digest(payload)
    }
    private static func digest(_ payload: BackupPayload) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var json = try JSONSerialization.jsonObject(with: encoder.encode(payload)) as? [String: Any] ?? [:]
        if var training = json["training"] as? [String: Any] {
            for key in ["favorites", "hidden"] { if let values = training[key] as? [String] { training[key] = values.sorted() } }
            if var profile = training["profile"] as? [String: Any], let values = profile["equipment"] as? [String] { profile["equipment"] = values.sorted(); training["profile"] = profile }
            json["training"] = training
        }
        return SHA256.hash(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])).map { String(format: "%02x", $0) }.joined()
    }
    func validate() throws {
        guard OwnerDates.valid(exportedAt) else { throw OwnerSystemError.invalid }
        guard schemaVersion == 1 else { throw InputError.invalid("This backup version is not supported by ASCEND V1.") }
        guard payloadSHA256 == (try Self.digest(payload)) else { throw InputError.invalid("The backup integrity check failed. Your current data has not changed.") }
        try payload.validate()
    }
    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 100_000_000 else { throw InputError.invalid("This backup is too large to open safely.") }
        let backup = try JSONDecoder().decode(Self.self, from: data); try backup.validate(); return backup
    }
}
struct BackupPayload: Codable, Sendable {
    var profile: BackupUserProfile
    var settings: BackupUserSettings
    var weights: [BackupBodyWeightEntry]
    var nutrition: [BackupNutritionEntry]
    var sleep: [BackupSleepEntry]
    var exercises: [BackupExercise]
    var sessions: [BackupWorkoutSession]
    var sessionExercises: [BackupWorkoutExercise]
    var sets: [BackupWorkoutSet]
    var records: [BackupPersonalRecord]
    var objectives: [BackupDailyObjective]
    var occurrences: [BackupDailyObjectiveCompletion]
    var evaluations: [BackupDailyEvaluation]
    var history: [BackupELOHistoryEntry]
    var explanations: [BackupBrainInsightRecord]
    var system: OwnerSystem
    var training: PersonalTrainingState
    var brain: BrainArchive
    var live: LiveWorkout?
    var summary: String { "\(profile.displayName) · \(sessions.count) workouts · \(weights.count) weigh-ins · \(nutrition.count) fuel logs · \(sleep.count) sleep logs · \(training.routines.count) routines · \(objectives.count) objectives · \(system.measurements.count) measurements" }
    func validate() throws {
        func require(_ value: Bool) throws { if !value { throw InputError.invalid("The backup contains invalid values or broken references. Your current data has not changed.") } }
        func unique<T: Hashable>(_ keys: [T]) -> Bool { keys.count == Set(keys).count }
        func validRecordKey(_ key: String) -> Bool {
            if RecordKind(rawValue: key) != nil { return true }
            let parts = key.split(separator: "@", omittingEmptySubsequences: false)
            guard parts.count == 2, ["reps", "totalReps"].contains(String(parts[0])), let load = Double(parts[1]) else { return false }
            return load.isFinite && (0...1000).contains(load)
        }
        func validContributions(_ data: Data) throws -> Bool {
            let values = try JSONDecoder().decode([MuscleContribution].self, from: data)
            return values.count <= Muscle.allCases.count && unique(values.map(\.muscle)) && values.allSatisfy { $0.fraction.isFinite && (0...1).contains($0.fraction) }
        }
        var dates = [profile.createdAt] + [profile.targetDeadline].compactMap { $0 }
        dates += weights.map(\.measuredAt); dates += nutrition.map(\.date)
        dates += sleep.flatMap { [$0.date] + [$0.bedtime, $0.wakeTime].compactMap { $0 } }
        dates += sessions.flatMap { [$0.startedAt] + [$0.completedAt].compactMap { $0 } }
        dates += sets.map(\.completedAt); dates += records.map(\.achievedAt); dates += objectives.map(\.startsAt)
        dates += occurrences.flatMap { [$0.date] + [$0.completedAt].compactMap { $0 } }
        dates += evaluations.flatMap { [$0.date, $0.evaluatedAt] }; dates += history.map(\.date); dates += explanations.map(\.createdAt)
        dates += brain.history.flatMap { [$0.date] + [$0.respondedAt].compactMap { $0 } }; dates += brain.preferences.map(\.date)
        try require(dates.allSatisfy(OwnerDates.valid))
        try system.validate()
        try require(profile.key == "owner" && settings.key == "settings" && !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && profile.displayName.count <= 40)
        try require((500...10_000).contains(profile.calorieGoal) && (10...600).contains(profile.proteinGoal) && (1...16).contains(profile.sleepTargetHours) && (0...1_000_000_000).contains(profile.lifetimeCredits) && profile.desiredWeeklyChangeKG.isFinite && abs(profile.desiredWeeklyChangeKG) <= 5)
        try require(profile.startingWeightKG.map { (20...400).contains($0) } ?? true)
        try require(profile.targetWeightKG.map { (20...400).contains($0) } ?? true)
        try require(TimeZone(identifier: settings.timeZoneIdentifier) != nil && (15...900).contains(settings.restTimerSeconds))
        try require(training.version == 1 && (15...180).contains(training.profile.sessionMinutes) && training.routines.count <= 100 && training.routines.allSatisfy(\.isValid))
        try require(brain.version == 1 && brain.history.count <= 180 && brain.preferences.count <= 300 && unique(brain.history.map(\.id)))
        try require(sets.count <= 500_000 && sessions.count <= 50_000 && occurrences.count <= 100_000)
        try require(unique(weights.map(\.id)) && unique(nutrition.map(\.dayKey)) && unique(sleep.map(\.dayKey)) && unique(exercises.map(\.catalogID)))
        try require(unique(sessions.map(\.id)) && unique(sessionExercises.map(\.id)) && unique(sets.map(\.id)) && unique(records.map(\.id)))
        try require(unique(objectives.map(\.id)) && unique(occurrences.map(\.occurrenceKey)) && unique(evaluations.map(\.dayKey)) && unique(history.map(\.dayKey)))
        let catalog = Set(exercises.map(\.catalogID)), sessionIDs = Set(sessions.map(\.id)), entryIDs = Set(sessionExercises.map(\.id)), objectiveIDs = Set(objectives.map(\.id)), days = Set(evaluations.map(\.dayKey))
        try require(training.favorites.union(training.hidden).isSubset(of: catalog) && training.routines.flatMap(\.exercises).allSatisfy { catalog.contains($0.exerciseID) })
        for entry in sessionExercises { try require(entry.sessionID.map { sessionIDs.contains($0) } == true && (entry.exerciseID.map { catalog.contains($0) } ?? true) && TrackingMode(rawValue: entry.trackingModeRaw) != nil); try require(validContributions(entry.contributionData)) }
        for set in sets { try require(set.parentID.map { entryIDs.contains($0) } == true && (0...2000).contains(set.reps) && (0...1000).contains(set.weightKG) && (0...86400).contains(set.durationSeconds) && (0...500000).contains(set.distanceMeters) && (set.perceivedExertion.map { (1...10).contains($0) } ?? true)) }
        for record in records { try require(sessionIDs.contains(record.sessionID) && catalog.contains(record.exerciseCatalogID) && record.value.isFinite && record.value >= 0 && validRecordKey(record.kindRaw)) }
        for exercise in exercises { try require(!exercise.catalogID.isEmpty && TrackingMode(rawValue: exercise.trackingModeRaw) != nil); try require(validContributions(exercise.contributionData)) }
        for objective in objectives { try require(objective.kindRaw != "exercise" || objective.exerciseCatalogID != nil); try require(ObjectiveKind(rawValue: objective.kindRaw) != nil && ObjectiveCadence(rawValue: objective.cadenceRaw) != nil && ObjectiveImportance(rawValue: objective.importanceRaw) != nil && objective.target.isFinite && (0.001...20000).contains(objective.target) && objective.weekdays.allSatisfy { (1...7).contains($0) } && (objective.exerciseCatalogID.map { catalog.contains($0) } ?? true)) }
        for occurrence in occurrences { try require((occurrence.objectiveID.map { objectiveIDs.contains($0) } ?? true) && occurrence.target.isFinite && (0.001...20000).contains(occurrence.target) && occurrence.value.isFinite && occurrence.value >= 0 && ObjectiveKind(rawValue: occurrence.kindRaw) != nil) }
        for evaluation in evaluations { try require((1...2).contains(evaluation.scoringVersion)); _ = try JSONDecoder().decode([ScoreComponent].self, from: evaluation.componentData) }
        for item in history { try require((item.evaluationKey.map { days.contains($0) } ?? true) && item.previousELO >= 0 && item.elo >= 0 && item.elo.subtractingReportingOverflow(item.previousELO).partialValue == item.delta) }
        for weight in weights { try require((20...400).contains(weight.kilograms)) }
        for food in nutrition { try require((0...20000).contains(food.calories) && (0...1000).contains(food.proteinGrams) && food.calorieGoal > 0 && food.proteinGoal > 0) }
        for night in sleep { try require((0.1...24).contains(night.durationHours) && (1...5).contains(night.quality)); if let start = night.bedtime, let end = night.wakeTime { try require(end > start && abs(end.timeIntervalSince(start) / 3600 - night.durationHours) < 0.05) } }
        for session in sessions { try require(session.completedAt.map { $0 >= session.startedAt } ?? true) }
        for item in history { if let key = item.evaluationKey { try require(key == item.dayKey && evaluations.first(where: { $0.dayKey == key })?.eloDelta == item.delta) } }
        if let live { try require(live.isStructurallyValid && live.exercises.allSatisfy { catalog.contains($0.catalogID) }) }
    }
    @MainActor func insert(into context: ModelContext) throws {
        try validate()
        context.insert(try profile.model()); context.insert(try settings.model())
        let exerciseModels = try exercises.map { try $0.model() }; exerciseModels.forEach { context.insert($0) }
        let catalog = Dictionary(uniqueKeysWithValues: exerciseModels.map { ($0.catalogID, $0) })
        let sessionModels = try sessions.map { try $0.model() }; sessionModels.forEach { context.insert($0) }
        let sessionMap = Dictionary(uniqueKeysWithValues: sessionModels.map { ($0.id, $0) })
        let entryModels = try sessionExercises.map { dto -> WorkoutExercise in
            let model = try dto.model(exercises: catalog); model.exercise = dto.exerciseID.flatMap { catalog[$0] }; model.session = dto.sessionID.flatMap { sessionMap[$0] }; context.insert(model); return model
        }
        let entries = Dictionary(uniqueKeysWithValues: entryModels.map { ($0.id, $0) })
        for dto in sets { let model = try dto.model(); model.workoutExercise = dto.parentID.flatMap { entries[$0] }; context.insert(model) }
        let objectiveModels = try objectives.map { try $0.model() }; objectiveModels.forEach { context.insert($0) }
        let objectivesByID = Dictionary(uniqueKeysWithValues: objectiveModels.map { ($0.id, $0) })
        for dto in occurrences { let model = try dto.model(objectives: objectivesByID); model.objective = dto.objectiveID.flatMap { objectivesByID[$0] }; context.insert(model) }
        let evaluationModels = try evaluations.map { try $0.model() }; evaluationModels.forEach { context.insert($0) }
        let evaluationsByDay = Dictionary(uniqueKeysWithValues: evaluationModels.map { ($0.dayKey, $0) })
        for dto in history { let model = try dto.model(); model.evaluation = dto.evaluationKey.flatMap { evaluationsByDay[$0] }; context.insert(model) }
        for dto in weights { context.insert(try dto.model()) }; for dto in nutrition { context.insert(try dto.model()) }; for dto in sleep { context.insert(try dto.model()) }
        for dto in records { context.insert(try dto.model()) }; for dto in explanations { context.insert(try dto.model()) }
        try context.save()
    }
}

extension AppStore {
    func backupEnvelope() throws -> AscendBackupEnvelope {
        try loadRecords()
        var system = ownerSystem
        if let values = localPreferences?.dictionary(forKey: "exercise-rest-v1") as? [String: Int] { system.exerciseRest.merge(values) { current, _ in current } }
        system.lastSeenDay = localPreferences?.string(forKey: "seen-daily-evaluation-v1") ?? system.lastSeenDay
        let payload = BackupPayload(profile: .init(profile), settings: .init(settings), weights: weights.map(BackupBodyWeightEntry.init), nutrition: nutrition.map(BackupNutritionEntry.init), sleep: sleep.map(BackupSleepEntry.init), exercises: exercises.map(BackupExercise.init), sessions: sessions.map(BackupWorkoutSession.init), sessionExercises: try context.fetch(FetchDescriptor<WorkoutExercise>()).map(BackupWorkoutExercise.init), sets: try context.fetch(FetchDescriptor<WorkoutSet>()).map(BackupWorkoutSet.init), records: records.map(BackupPersonalRecord.init), objectives: objectives.map(BackupDailyObjective.init), occurrences: occurrences.map(BackupDailyObjectiveCompletion.init), evaluations: evaluations.map(BackupDailyEvaluation.init), history: history.map(BackupELOHistoryEntry.init), explanations: try context.fetch(FetchDescriptor<BrainInsightRecord>()).map(BackupBrainInsightRecord.init), system: system, training: training, brain: brainArchive, live: activeWorkout)
        try payload.validate(); return try .init(payload: payload, date: actionDate())
    }
    @discardableResult func replaceOwnerData(with backup: AscendBackupEnvelope?) -> Bool {
        do {
            try backup?.validate()
            if !container.configurations.allSatisfy(\.isStoredInMemoryOnly), ownerStorage?.url.path.contains("ASCEND-UITests-") == true {
                throw InputError.invalid("Persistent test fixtures cannot replace the production owner store.")
            }
            let memory = container.configurations.allSatisfy(\.isStoredInMemoryOnly)
            let folder = try memory ? nil : OwnerStoreLocation.stagingFolder()
            let replacementDate = actionDate()
            let candidate = try AppStore(container: PersistenceController.makeContainer(inMemory: memory, folder: folder), now: replacementDate, clock: { memory ? replacementDate : Date.now }, storageFolder: folder, restored: backup?.payload, activateServices: false)
            if backup == nil { var clean = PersonalTrainingState(); clean.routines = []; candidate.training = clean; candidate.brainArchive = .init(); candidate.ownerSystem = .init(); candidate.activeWorkout = nil }
            try candidate.context.save()
            try candidate.ownerStorage?.write(candidate.ownerSystem); try candidate.trainingStorage?.write(candidate.training); try candidate.brainStorage?.write(candidate.brainArchive); try candidate.workoutStorage?.write(candidate.activeWorkout)
            if let folder {
                let files = container.configurations.flatMap { [$0.url, $0.url.appendingPathExtension("wal"), $0.url.appendingPathExtension("shm"), URL(fileURLWithPath: $0.url.path + "-wal"), URL(fileURLWithPath: $0.url.path + "-shm")] } + [ownerStorage?.url, trainingStorage?.url, brainStorage?.url, workoutStorage?.url].compactMap { $0 }
                try JSONEncoder().encode(files.map(\.path)).write(to: folder.appendingPathComponent("retired-files.json"), options: .atomic)
                try OwnerStoreLocation.commit(folder)
                UserDefaults.standard.removeObject(forKey: "exercise-rest-v1"); UserDefaults.standard.removeObject(forKey: "seen-daily-evaluation-v1")
            }
            if !memory { RestNotifications.synchronize(candidate.activeWorkout?.rest, enabled: !AppMotion.snapshotMode); RestLiveActivity.synchronize(candidate.activeWorkout, enabled: !AppMotion.snapshotMode) }
            replacementStore = candidate; replacementID = UUID()
            return true
        } catch { errorMessage = "No data replaced: \(error.localizedDescription)"; return false }
    }
}
