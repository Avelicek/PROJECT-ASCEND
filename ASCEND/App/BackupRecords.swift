// Structured V1 backup records. Fields intentionally mirror persisted values, including historical snapshots.
import Foundation
import SwiftData

struct BackupUserProfile: Codable, Sendable {
    var key: String
    var displayName: String
    var createdAt: Date
    var startingWeightKG: Double?
    var targetWeightKG: Double?
    var targetDeadline: Date?
    var desiredWeeklyChangeKG: Double
    var calorieGoal: Double
    var proteinGoal: Double
    var sleepTargetHours: Double
    var lifetimeCredits: Int
    @MainActor init(_ source: UserProfile) {
        key = source.key
        displayName = source.displayName
        createdAt = source.createdAt
        startingWeightKG = source.startingWeightKG
        targetWeightKG = source.targetWeightKG
        targetDeadline = source.targetDeadline
        desiredWeeklyChangeKG = source.desiredWeeklyChangeKG
        calorieGoal = source.calorieGoal
        proteinGoal = source.proteinGoal
        sleepTargetHours = source.sleepTargetHours
        lifetimeCredits = source.lifetimeCredits
    }
    @MainActor func model() throws -> UserProfile {
        let model = UserProfile()
        model.key = key
        model.displayName = displayName
        model.createdAt = createdAt
        model.startingWeightKG = startingWeightKG
        model.targetWeightKG = targetWeightKG
        model.targetDeadline = targetDeadline
        model.desiredWeeklyChangeKG = desiredWeeklyChangeKG
        model.calorieGoal = calorieGoal
        model.proteinGoal = proteinGoal
        model.sleepTargetHours = sleepTargetHours
        model.lifetimeCredits = lifetimeCredits
        return model
    }
}

struct BackupUserSettings: Codable, Sendable {
    var key: String
    var timeZoneIdentifier: String
    var onDeviceAIEnabled: Bool
    var hapticsEnabled: Bool
    var automaticRestTimer: Bool
    var restTimerSeconds: Int
    var appearance: String
    @MainActor init(_ source: UserSettings) {
        key = source.key
        timeZoneIdentifier = source.timeZoneIdentifier
        onDeviceAIEnabled = source.onDeviceAIEnabled
        hapticsEnabled = source.hapticsEnabled
        automaticRestTimer = source.automaticRestTimer
        restTimerSeconds = source.restTimerSeconds
        appearance = source.appearance
    }
    @MainActor func model() throws -> UserSettings {
        let model = UserSettings()
        model.key = key
        model.timeZoneIdentifier = timeZoneIdentifier
        model.onDeviceAIEnabled = onDeviceAIEnabled
        model.hapticsEnabled = hapticsEnabled
        model.automaticRestTimer = automaticRestTimer
        model.restTimerSeconds = restTimerSeconds
        model.appearance = appearance
        return model
    }
}

struct BackupBodyWeightEntry: Codable, Sendable {
    var id: UUID
    var measuredAt: Date
    var kilograms: Double
    @MainActor init(_ source: BodyWeightEntry) {
        id = source.id
        measuredAt = source.measuredAt
        kilograms = source.kilograms
    }
    @MainActor func model() throws -> BodyWeightEntry {
        let model = BodyWeightEntry(measuredAt: measuredAt, kilograms: kilograms)
        model.id = id
        model.measuredAt = measuredAt
        model.kilograms = kilograms
        return model
    }
}

struct BackupNutritionEntry: Codable, Sendable {
    var dayKey: String
    var date: Date
    var calories: Double
    var proteinGrams: Double
    var calorieGoal: Double
    var proteinGoal: Double
    @MainActor init(_ source: NutritionEntry) {
        dayKey = source.dayKey
        date = source.date
        calories = source.calories
        proteinGrams = source.proteinGrams
        calorieGoal = source.calorieGoal
        proteinGoal = source.proteinGoal
    }
    @MainActor func model() throws -> NutritionEntry {
        let model = NutritionEntry(dayKey: dayKey, date: date, calories: calories, proteinGrams: proteinGrams, calorieGoal: calorieGoal, proteinGoal: proteinGoal)
        model.dayKey = dayKey
        model.date = date
        model.calories = calories
        model.proteinGrams = proteinGrams
        model.calorieGoal = calorieGoal
        model.proteinGoal = proteinGoal
        return model
    }
}

struct BackupSleepEntry: Codable, Sendable {
    var date: Date
    var dayKey: String
    var durationHours: Double
    var bedtime: Date?
    var wakeTime: Date?
    var quality: Int
    @MainActor init(_ source: SleepEntry) {
        date = source.date
        dayKey = source.dayKey
        durationHours = source.durationHours
        bedtime = source.bedtime
        wakeTime = source.wakeTime
        quality = source.quality
    }
    @MainActor func model() throws -> SleepEntry {
        let model = SleepEntry(dayKey: dayKey, date: date, durationHours: durationHours, quality: quality)
        model.dayKey = dayKey
        model.durationHours = durationHours
        model.bedtime = bedtime
        model.wakeTime = wakeTime
        model.quality = quality
        model.date = date
        return model
    }
}

struct BackupExercise: Codable, Sendable {
    var catalogID: String
    var name: String
    var categoryRaw: String
    var equipmentRaw: String
    var trackingModeRaw: String
    var bodyweightCapable: Bool
    var additionalWeightAllowed: Bool
    var contributionData: Data
    var primaryMuscleNames: [String]
    @MainActor init(_ source: Exercise) {
        catalogID = source.catalogID
        name = source.name
        categoryRaw = source.categoryRaw
        equipmentRaw = source.equipmentRaw
        trackingModeRaw = source.trackingModeRaw
        bodyweightCapable = source.bodyweightCapable
        additionalWeightAllowed = source.additionalWeightAllowed
        contributionData = source.contributionData
        primaryMuscleNames = source.primaryMuscleNames
    }
    @MainActor func model() throws -> Exercise {
        let model = Exercise(catalogID: catalogID, name: name, category: .strength, equipment: .none, trackingMode: .reps, bodyweightCapable: bodyweightCapable, additionalWeightAllowed: additionalWeightAllowed, contributions: [])
        model.catalogID = catalogID
        model.name = name
        model.categoryRaw = categoryRaw
        model.equipmentRaw = equipmentRaw
        model.trackingModeRaw = trackingModeRaw
        model.bodyweightCapable = bodyweightCapable
        model.additionalWeightAllowed = additionalWeightAllowed
        model.contributionData = contributionData
        model.primaryMuscleNames = primaryMuscleNames
        return model
    }
}

struct BackupWorkoutSession: Codable, Sendable {
    var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var title: String
    var isQuickLog: Bool
    var notes: String
    @MainActor init(_ source: WorkoutSession) {
        id = source.id
        startedAt = source.startedAt
        completedAt = source.completedAt
        title = source.title
        isQuickLog = source.isQuickLog
        notes = source.notes
    }
    @MainActor func model() throws -> WorkoutSession {
        let model = WorkoutSession(startedAt: startedAt, title: title, isQuickLog: isQuickLog)
        model.id = id
        model.startedAt = startedAt
        model.completedAt = completedAt
        model.title = title
        model.isQuickLog = isQuickLog
        model.notes = notes
        return model
    }
}

struct BackupWorkoutExercise: Codable, Sendable {
    var contributionData: Data
    var id: UUID
    var order: Int
    var exerciseName: String
    var trackingModeRaw: String
    var sessionID: UUID?
    var exerciseID: String?
    @MainActor init(_ source: WorkoutExercise) {
        contributionData = source.contributionData
        id = source.id
        order = source.order
        exerciseName = source.exerciseName
        trackingModeRaw = source.trackingModeRaw
        sessionID = source.session?.id
        exerciseID = source.exercise?.catalogID
    }
    @MainActor func model(exercises: [String: Exercise]) throws -> WorkoutExercise {
        let model = WorkoutExercise(exercise: exercises[exerciseID ?? ""] ?? Exercise(catalogID: "archived", name: exerciseName, category: .strength, equipment: .none, trackingMode: .reps, bodyweightCapable: false, additionalWeightAllowed: false, contributions: []), order: order)
        model.id = id
        model.order = order
        model.exerciseName = exerciseName
        model.trackingModeRaw = trackingModeRaw
        model.contributionData = contributionData
        return model
    }
}

struct BackupWorkoutSet: Codable, Sendable {
    var id: UUID
    var order: Int
    var reps: Int
    var weightKG: Double
    var durationSeconds: Double
    var distanceMeters: Double
    var perceivedExertion: Double?
    var isWarmup: Bool
    var completedAt: Date
    var parentID: UUID?
    @MainActor init(_ source: WorkoutSet) {
        id = source.id
        order = source.order
        reps = source.reps
        weightKG = source.weightKG
        durationSeconds = source.durationSeconds
        distanceMeters = source.distanceMeters
        perceivedExertion = source.perceivedExertion
        isWarmup = source.isWarmup
        completedAt = source.completedAt
        parentID = source.workoutExercise?.id
    }
    @MainActor func model() throws -> WorkoutSet {
        let model = WorkoutSet(order: order, performance: .init(reps: 0), completedAt: completedAt)
        model.id = id
        model.order = order
        model.reps = reps
        model.weightKG = weightKG
        model.durationSeconds = durationSeconds
        model.distanceMeters = distanceMeters
        model.perceivedExertion = perceivedExertion
        model.isWarmup = isWarmup
        model.completedAt = completedAt
        return model
    }
}

struct BackupPersonalRecord: Codable, Sendable {
    var id: UUID
    var exerciseCatalogID: String
    var kindRaw: String
    var value: Double
    var achievedAt: Date
    var sessionID: UUID
    @MainActor init(_ source: PersonalRecord) {
        id = source.id
        exerciseCatalogID = source.exerciseCatalogID
        kindRaw = source.kindRaw
        value = source.value
        achievedAt = source.achievedAt
        sessionID = source.sessionID
    }
    @MainActor func model() throws -> PersonalRecord {
        let model = PersonalRecord(exerciseCatalogID: exerciseCatalogID, kind: .reps, value: value, achievedAt: achievedAt, sessionID: sessionID)
        model.id = id
        model.exerciseCatalogID = exerciseCatalogID
        model.kindRaw = kindRaw
        model.value = value
        model.achievedAt = achievedAt
        model.sessionID = sessionID
        return model
    }
}

struct BackupDailyObjective: Codable, Sendable {
    var id: UUID
    var title: String
    var kindRaw: String
    var cadenceRaw: String
    var importanceRaw: String
    var target: Double
    var unit: String
    var startsAt: Date
    var weekdays: [Int]
    var isActive: Bool
    var exerciseCatalogID: String?
    @MainActor init(_ source: DailyObjective) {
        id = source.id
        title = source.title
        kindRaw = source.kindRaw
        cadenceRaw = source.cadenceRaw
        importanceRaw = source.importanceRaw
        target = source.target
        unit = source.unit
        startsAt = source.startsAt
        weekdays = source.weekdays
        isActive = source.isActive
        exerciseCatalogID = source.exerciseCatalogID
    }
    @MainActor func model() throws -> DailyObjective {
        let model = DailyObjective(title: title, kind: .custom, cadence: .daily, importance: .standard, target: target, unit: unit, startsAt: startsAt)
        model.id = id
        model.title = title
        model.kindRaw = kindRaw
        model.cadenceRaw = cadenceRaw
        model.importanceRaw = importanceRaw
        model.target = target
        model.unit = unit
        model.startsAt = startsAt
        model.weekdays = weekdays
        model.isActive = isActive
        model.exerciseCatalogID = exerciseCatalogID
        return model
    }
}

struct BackupDailyObjectiveCompletion: Codable, Sendable {
    var occurrenceKey: String
    var dayKey: String
    var date: Date
    var title: String
    var kindRaw: String
    var importanceRaw: String
    var target: Double
    var unit: String
    var value: Double
    var completedAt: Date?
    var recoveryExempt: Bool
    var replacementTitle: String?
    var objectiveID: UUID?
    @MainActor init(_ source: DailyObjectiveCompletion) {
        occurrenceKey = source.occurrenceKey
        dayKey = source.dayKey
        date = source.date
        title = source.title
        kindRaw = source.kindRaw
        importanceRaw = source.importanceRaw
        target = source.target
        unit = source.unit
        value = source.value
        completedAt = source.completedAt
        recoveryExempt = source.recoveryExempt
        replacementTitle = source.replacementTitle
        objectiveID = source.objective?.id
    }
    @MainActor func model(objectives: [UUID: DailyObjective]) throws -> DailyObjectiveCompletion {
        let model = DailyObjectiveCompletion(objective: objectives[objectiveID ?? UUID()] ?? DailyObjective(title: title, kind: .custom, cadence: .daily, importance: .standard, target: target, unit: unit, startsAt: date), date: date, policy: .init(timeZoneIdentifier: "UTC"))
        model.occurrenceKey = occurrenceKey
        model.dayKey = dayKey
        model.date = date
        model.title = title
        model.kindRaw = kindRaw
        model.importanceRaw = importanceRaw
        model.target = target
        model.unit = unit
        model.value = value
        model.completedAt = completedAt
        model.recoveryExempt = recoveryExempt
        model.replacementTitle = replacementTitle
        return model
    }
}

struct BackupDailyEvaluation: Codable, Sendable {
    var dayKey: String
    var date: Date
    var evaluatedAt: Date
    var scoringVersion: Int
    var componentData: Data
    var eloDelta: Int
    @MainActor init(_ source: DailyEvaluation) {
        dayKey = source.dayKey
        date = source.date
        evaluatedAt = source.evaluatedAt
        scoringVersion = source.scoringVersion
        componentData = source.componentData
        eloDelta = source.eloDelta
    }
    @MainActor func model() throws -> DailyEvaluation {
        let model = try DailyEvaluation(dayKey: dayKey, date: date, result: ELOEngine().evaluate(.init(), previousELO: 0), evaluatedAt: evaluatedAt)
        model.dayKey = dayKey
        model.date = date
        model.evaluatedAt = evaluatedAt
        model.scoringVersion = scoringVersion
        model.componentData = componentData
        model.eloDelta = eloDelta
        return model
    }
}

struct BackupELOHistoryEntry: Codable, Sendable {
    var dayKey: String
    var date: Date
    var previousELO: Int
    var elo: Int
    var delta: Int
    var evaluationKey: String?
    @MainActor init(_ source: ELOHistoryEntry) {
        dayKey = source.dayKey
        date = source.date
        previousELO = source.previousELO
        elo = source.elo
        delta = source.delta
        evaluationKey = source.evaluation?.dayKey
    }
    @MainActor func model() throws -> ELOHistoryEntry {
        let model = ELOHistoryEntry(dayKey: dayKey, date: date, previousELO: previousELO, elo: elo, delta: delta)
        model.dayKey = dayKey
        model.date = date
        model.previousELO = previousELO
        model.elo = elo
        model.delta = delta
        return model
    }
}

struct BackupBrainInsightRecord: Codable, Sendable {
    var id: UUID
    var createdAt: Date
    var contextFingerprint: String
    var payload: Data
    @MainActor init(_ source: BrainInsightRecord) {
        id = source.id
        createdAt = source.createdAt
        contextFingerprint = source.contextFingerprint
        payload = source.payload
    }
    @MainActor func model() throws -> BrainInsightRecord {
        let model = try BrainInsightRecord(insight: JSONDecoder().decode(BrainInsight.self, from: payload), createdAt: createdAt, contextFingerprint: contextFingerprint)
        model.id = id
        model.createdAt = createdAt
        model.contextFingerprint = contextFingerprint
        model.payload = payload
        return model
    }
}
