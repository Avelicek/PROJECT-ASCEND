import Foundation
import Observation
import SwiftData

enum InputError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): message } }
}

@MainActor @Observable final class AppStore {
    let container: ModelContainer
    let context: ModelContext
    let profile: UserProfile
    let settings: UserSettings
    let isDemo: Bool
    var presentedSheet: LogDestination?
    var navigationRequest: AppDestination?
    var errorMessage: String?
    var revision = 0
    var now: Date = .now
    var weights: [BodyWeightEntry] = []
    var nutrition: [NutritionEntry] = []
    var sleep: [SleepEntry] = []
    var exercises: [Exercise] = []
    var sessions: [WorkoutSession] = []
    var objectives: [DailyObjective] = []
    var occurrences: [DailyObjectiveCompletion] = []
    var evaluations: [DailyEvaluation] = []
    var history: [ELOHistoryEntry] = []
    var records: [PersonalRecord] = []
    var activityLoads: [TrainingLoad] = []
    @ObservationIgnored var activityStimulus: [UUID: Double] = [:]
    var progress: ProgressReport
    var readiness: ReadinessReport
    var personalModel: PersonalModel
    var protectedDays: [Date] = []
    var projectedScore: ELOResult = ELOEngine().evaluate(.init(), previousELO: 0)
    var goalProjection = ProjectionEngine().weight(samples: [], target: nil, now: .distantPast, policy: DayPolicy(timeZoneIdentifier: "UTC"))
    var nextBestAction = NextBestAction(action: .checkIn, title: "Start your check-in", reason: "Learning your baseline.", button: "Check in", opportunity: nil)
    var activeWorkout: LiveWorkout?
    var liveWorkoutPresented = false
    var completedWorkout: CompletedWorkoutSummary?
    var ownerSystem = OwnerSystem()
    var replacementStore: AppStore?
    var replacementID = UUID()
    @ObservationIgnored var ownerStorage: OwnerSystemStorage?
    var training = PersonalTrainingState()
    var brainArchive = BrainArchive()
    var personalContext = PersonalContext(date: .distantPast)
    var brainDecision = PersonalBrainEngine().decide(PersonalContext(date: .distantPast))
    @ObservationIgnored var brainStorage: BrainStorage?
    @ObservationIgnored var brainStorageUnavailable = false
    @ObservationIgnored var brainInputKey: Int?
    @ObservationIgnored let trainingStorage: PersonalTrainingStorage?
    @ObservationIgnored let workoutStorage: WorkoutDraftStorage?
    @ObservationIgnored let localPreferences: UserDefaults?
    @ObservationIgnored private let currentDate: () -> Date

    var policy: DayPolicy { DayPolicy(timeZoneIdentifier: settings.timeZoneIdentifier) }
    var todayNutrition: NutritionEntry? { nutrition.first { $0.dayKey == policy.key(for: now) } }
    var todaySleep: SleepEntry? { sleep.first { $0.dayKey == policy.key(for: now) } }
    var todayObjectives: [DailyObjectiveCompletion] { occurrences.filter { $0.dayKey == policy.key(for: now) } }
    var currentELO: Int { history.last?.elo ?? 0 }
    var rank: RankStatus { RankEngine().status(elo: currentELO) }
    var lifetimeLevel: Int { ELOEngine().lifetimeLevel(credits: profile.lifetimeCredits) }

    init(container: ModelContainer, demo: Bool = false, now: Date = .now, clock: @escaping () -> Date = { .now }, workoutStorage: WorkoutDraftStorage? = nil, trainingStorage: PersonalTrainingStorage? = nil, brainStorage: BrainStorage? = nil, storageFolder: URL? = nil, restored: BackupPayload? = nil, activateServices: Bool = true) throws {
        let modelContext = ModelContext(container)
        modelContext.autosaveEnabled = false
        if let restored { try restored.insert(into: modelContext) }
        if demo {
            guard container.configurations.allSatisfy({ $0.isStoredInMemoryOnly }) else {
                throw InputError.invalid("Demo data requires an in-memory container.")
            }
            try PreviewData.populate(context: modelContext, now: now)
        }
        let existingOwner = try modelContext.fetch(FetchDescriptor<UserProfile>()).first
        let owner = existingOwner ?? UserProfile(createdAt: now)
        let preferences = try modelContext.fetch(FetchDescriptor<UserSettings>()).first ?? UserSettings()
        if owner.modelContext == nil { modelContext.insert(owner) }
        if preferences.modelContext == nil { modelContext.insert(preferences) }
        let dayPolicy = DayPolicy(timeZoneIdentifier: preferences.timeZoneIdentifier)
        self.container = container; self.context = modelContext; self.isDemo = demo; self.now = now; self.currentDate = clock
        self.profile = owner; self.settings = preferences
        let memoryOnly = container.configurations.allSatisfy { $0.isStoredInMemoryOnly }
        self.workoutStorage = try workoutStorage ?? storageFolder.map { WorkoutDraftStorage(url: $0.appendingPathComponent("active-workout-v1.json")) } ?? (memoryOnly ? nil : WorkoutDraftStorage.production())
        let productionFolder = try storageFolder ?? (memoryOnly ? nil : OwnerStoreLocation.selectedFolder())
        self.localPreferences = memoryOnly || productionFolder?.lastPathComponent != "ASCEND" ? nil : UserDefaults.standard
        let personalStorage = try trainingStorage ?? storageFolder.map { PersonalTrainingStorage(url: $0.appendingPathComponent("personal-training-v1.json")) } ?? (memoryOnly ? nil : PersonalTrainingStorage.production())
        self.trainingStorage = personalStorage
        self.training = try restored?.training ?? personalStorage?.read() ?? PersonalTrainingState()

        // Initialize every required stored property before accessing self-backed state below.
        // Xcode 27 correctly rejects touching ownerSystem/localPreferences via self while
        // progress/readiness/personalModel are still uninitialized.
        self.progress = ProgressEngine().report(samples: [], start: nil, target: nil, desiredWeeklyChange: 0.25, now: now, policy: dayPolicy)
        self.readiness = RecoveryEngine().evaluate(loads: [], context: .init(), now: now)
        self.personalModel = PersonalModel(weights: [], nutrition: [], sleep: [], workoutDates: [], now: now, policy: dayPolicy)

        let ownerFolder = productionFolder
        self.ownerStorage = ownerFolder.map { OwnerSystemStorage(url: $0.appendingPathComponent("owner-system-v1.json")) }
        if let state = try restored?.system ?? ownerStorage?.read() { self.ownerSystem = state }
        else {
            self.ownerSystem.onboardingComplete = demo || existingOwner != nil
            self.ownerSystem.exerciseRest = localPreferences?.dictionary(forKey: "exercise-rest-v1") as? [String: Int] ?? [:]
            self.ownerSystem.lastSeenDay = localPreferences?.string(forKey: "seen-daily-evaluation-v1")
            try ownerStorage?.write(ownerSystem)
        }
        self.brainStorage = try brainStorage ?? storageFolder.map { BrainStorage(url: $0.appendingPathComponent("personal-brain-v1.json")) } ?? (memoryOnly ? nil : BrainStorage.production())
        do { self.brainArchive = try restored?.brain ?? self.brainStorage?.read() ?? BrainArchive() }
        catch { self.brainStorageUnavailable = true; self.errorMessage = "Brain history file preserved: \(error.localizedDescription)" }
        if demo {
            self.training.profile.equipment = [.bodyweight, .dumbbells, .pullUpBar, .latPulldown, .chestPress]
            self.training.favorites = ["db_row", "lat_pulldown", "push_up", "chest_press"]
        }
        try ExerciseCatalog.seed(in: modelContext)
        try refresh(at: now)
        do {
            if let draft = try restored?.live ?? self.workoutStorage?.read(), !sessions.contains(where: { $0.id == draft.id }) { activeWorkout = draft }
        } catch { errorMessage = "Unfinished workout file preserved: \(error.localizedDescription)" }
        if activeWorkout != nil { deriveBrain() }
        if activateServices && !memoryOnly && !AppMotion.snapshotMode {
            RestNotifications.synchronize(activeWorkout?.rest, enabled: (ownerSystem.coachPreferences ?? .init()).enabled.contains(.rest))
            RestLiveActivity.synchronize(activeWorkout, enabled: true)
        }
        #if DEBUG
        try PreviewData.preparePresentationFixture(store: self)
        #endif
    }

    func refresh(at date: Date = .now) throws {
        now = date
        try loadRecords()
        rebuildActivityLoads()
        materializeToday()
        synchronizeToday()
        try finalizeClosedDays()
        try loadRecords()
        deriveState()
        try context.save()
        revision += 1
    }

    func refreshSafely() {
        do { try refresh(at: currentDate()) } catch { recover(from: error) }
    }
    func actionDate() -> Date { currentDate() }

    func perform(_ change: () throws -> Void) -> Bool {
        do { now = currentDate(); try refresh(at: now); try change(); try refresh(at: now); return true }
        catch { recover(from: error); return false }
    }
    private func recover(from error: Error) {
        context.rollback()
        errorMessage = error.localizedDescription
        do { try loadRecords(); rebuildActivityLoads(); deriveState(); revision += 1 } catch { errorMessage = error.localizedDescription }
    }

    func loadRecords() throws {
        // Keep model access and sorting on MainActor without sending model key paths to SortDescriptor.
        weights = try context.fetch(FetchDescriptor<BodyWeightEntry>()).sorted { $0.measuredAt < $1.measuredAt }
        nutrition = try context.fetch(FetchDescriptor<NutritionEntry>()).sorted { $0.date < $1.date }
        sleep = try context.fetch(FetchDescriptor<SleepEntry>()).sorted { $0.date < $1.date }
        exercises = try context.fetch(FetchDescriptor<Exercise>()).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        sessions = try context.fetch(FetchDescriptor<WorkoutSession>()).sorted { $0.startedAt > $1.startedAt }
        objectives = try context.fetch(FetchDescriptor<DailyObjective>()).sorted { $0.startsAt < $1.startsAt }
        occurrences = try context.fetch(FetchDescriptor<DailyObjectiveCompletion>()).sorted { $0.date < $1.date }
        evaluations = try context.fetch(FetchDescriptor<DailyEvaluation>()).sorted { $0.date < $1.date }
        history = try context.fetch(FetchDescriptor<ELOHistoryEntry>()).sorted { $0.date < $1.date }
        records = try context.fetch(FetchDescriptor<PersonalRecord>()).sorted { $0.achievedAt > $1.achievedAt }
    }

    private func materializeToday() {
        for objective in objectives where objective.isActive && ObjectiveEngine().isDue(objective.schedule, on: now, policy: policy) {
            let key = "\(objective.id.uuidString):\(policy.key(for: now))"
            if !occurrences.contains(where: { $0.occurrenceKey == key }) {
                let occurrence = DailyObjectiveCompletion(objective: objective, date: now, policy: policy)
                context.insert(occurrence); occurrences.append(occurrence)
            }
        }
    }

    private func synchronizeToday() {
        for occurrence in todayObjectives {
            let trainingKind = [ObjectiveKind.exercise, .workout].contains(ObjectiveKind(rawValue: occurrence.kindRaw) ?? .custom)
            let kind = ObjectiveKind(rawValue: occurrence.kindRaw) ?? .custom
            if kind == .exercise, let id = occurrence.objective?.exerciseCatalogID {
                occurrence.value = sessions.filter { policy.sameDay($0.evaluationDate, now) && $0.hasWorkingSets }
                    .flatMap(\.exercises).filter { $0.exercise?.catalogID == id }.flatMap(\.sets)
                    .filter { !$0.isWarmup }.reduce(0) { $0 + (occurrence.unit == "seconds" ? $1.durationSeconds : Double($1.reps)) }
            } else if kind == .sleep { occurrence.value = todaySleep?.durationHours ?? 0
            } else {
                occurrence.value = ObjectiveEngine().value(kind: kind, manual: occurrence.value,
                    calories: todayNutrition?.calories, protein: todayNutrition?.proteinGrams,
                    weighed: weights.contains { policy.sameDay($0.measuredAt, now) },
                    workedOut: sessions.contains { policy.sameDay($0.evaluationDate, now) && $0.hasWorkingSets })
            }
            occurrence.completedAt = occurrence.value >= occurrence.target ? occurrence.completedAt ?? now : nil
            if trainingKind && occurrence.completedAt != nil {
                // Protection never erases real recorded performance or turns it into duplicate load.
                occurrence.recoveryExempt = false; occurrence.replacementTitle = nil
            } else if trainingKind && ownerSystem.protectsTraining(on: occurrence.date, policy: policy) {
                occurrence.recoveryExempt = true; occurrence.replacementTitle = "Sick Mode · protected"
            }
        }
    }

    private func deriveState() {
        var protected = Set<Date>()
        let earliest = (sessions.map(\.startedAt) + occurrences.map(\.date)).min() ?? policy.start(of: now)
        for interval in ownerSystem.sickIntervals {
            var day = policy.start(of: max(earliest, interval.start))
            let end = policy.start(of: min(now, interval.end ?? now))
            while day <= end && protected.count < 36_500 { protected.insert(day); day = policy.adding(days: 1, to: day) }
        }
        protectedDays = protected.sorted()
        let weightSamples = weights.map { WeightSample(date: $0.measuredAt, kilograms: $0.kilograms) }
        let nutritionSamples = nutrition.map { NutritionSample(date: $0.date, calories: $0.calories, protein: $0.proteinGrams) }
        let sleepSamples = sleep.map { SleepSample(date: $0.date, hours: $0.durationHours, quality: $0.quality) }
        progress = ProgressEngine().report(samples: weightSamples, start: profile.startingWeightKG, target: profile.targetWeightKG,
            desiredWeeklyChange: profile.desiredWeeklyChangeKG, now: now, policy: policy)
        personalModel = PersonalModel(weights: weightSamples, nutrition: nutritionSamples, sleep: sleepSamples,
            workoutDates: sessions.filter { $0.hasWorkingSets }.map(\.evaluationDate), now: now, policy: policy)
        let recentStart = policy.adding(days: -2, to: policy.start(of: now))
        let recentNutrition = nutrition.filter { $0.date >= recentStart && $0.date <= now }
        let recentSleep = sleep.last { $0.date <= now && $0.date >= policy.adding(days: -1, to: policy.start(of: now)) }
        let context = RecoveryContext(sleepHours: recentSleep?.durationHours, sleepQuality: recentSleep?.quality,
            sleepTarget: profile.sleepTargetHours,
            calorieAdherence: FitnessMath.average(recentNutrition.map { $0.calories / max(1, $0.calorieGoal) }),
            proteinAdherence: FitnessMath.average(recentNutrition.map { $0.proteinGrams / max(1, $0.proteinGoal) }),
            tolerance: personalModel.recoveryTolerance,
            historyDays: sessions.filter { $0.hasWorkingSets }.last.map { max(0, Int(now.timeIntervalSince($0.startedAt) / 86400)) } ?? 0,
            trainingSessions: sessions.filter { $0.hasWorkingSets }.count)
        let loads = canonicalLoads
        readiness = RecoveryEngine().evaluate(loads: loads, context: context, now: now)
        projectedScore = DailyELOEngine().evaluate(dailyScoreInput(for: now), previousELO: currentELO)
        deriveBrain()
        goalProjection = ProjectionEngine().weight(samples: weightSamples, target: profile.targetWeightKG, now: now, policy: policy)
        nextBestAction = makeNextBestAction()

    }

    func report(window: EvaluationWindow) -> ProgressReport {
        ProgressEngine().report(samples: weights.map { .init(date: $0.measuredAt, kilograms: $0.kilograms) },
            start: profile.startingWeightKG, target: profile.targetWeightKG, desiredWeeklyChange: profile.desiredWeeklyChangeKG,
            window: window, now: now, policy: policy)
    }

}
