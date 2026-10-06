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
    var progress: ProgressReport
    var readiness: ReadinessReport
    var personalModel: PersonalModel
    var insight: BrainInsight
    var projectedScore: ELOResult = ELOEngine().evaluate(.init(), previousELO: 0)
    @ObservationIgnored private let currentDate: () -> Date
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var lastAnalyzedContext: Data?
    @ObservationIgnored private var lastAnalysisAt: Date?

    var policy: DayPolicy { DayPolicy(timeZoneIdentifier: settings.timeZoneIdentifier) }
    var todayNutrition: NutritionEntry? { nutrition.first { $0.dayKey == policy.key(for: now) } }
    var todaySleep: SleepEntry? { sleep.first { $0.dayKey == policy.key(for: now) } }
    var todayObjectives: [DailyObjectiveCompletion] { occurrences.filter { $0.dayKey == policy.key(for: now) } }
    var currentELO: Int { history.last?.elo ?? 0 }
    var rank: RankStatus { RankEngine().status(elo: currentELO) }
    var lifetimeLevel: Int { ELOEngine().lifetimeLevel(credits: profile.lifetimeCredits) }

    init(container: ModelContainer, demo: Bool = false, now: Date = .now, clock: @escaping () -> Date = { .now }) throws {
        let modelContext = ModelContext(container)
        modelContext.autosaveEnabled = false
        if demo {
            guard container.configurations.allSatisfy({ $0.isStoredInMemoryOnly }) else {
                throw InputError.invalid("Demo data requires an in-memory container.")
            }
            try PreviewData.populate(context: modelContext, now: now)
        }
        let owner = try modelContext.fetch(FetchDescriptor<UserProfile>()).first ?? UserProfile(createdAt: now)
        let preferences = try modelContext.fetch(FetchDescriptor<UserSettings>()).first ?? UserSettings()
        if owner.modelContext == nil { modelContext.insert(owner) }
        if preferences.modelContext == nil { modelContext.insert(preferences) }
        let dayPolicy = DayPolicy(timeZoneIdentifier: preferences.timeZoneIdentifier)
        self.container = container; self.context = modelContext; self.isDemo = demo; self.now = now; self.currentDate = clock
        self.profile = owner; self.settings = preferences
        self.progress = ProgressEngine().report(samples: [], start: nil, target: nil, desiredWeeklyChange: 0.25, now: now, policy: dayPolicy)
        self.readiness = RecoveryEngine().evaluate(loads: [], context: .init(), now: now)
        self.personalModel = PersonalModel(weights: [], nutrition: [], sleep: [], workoutDates: [], now: now, policy: dayPolicy)
        self.insight = DeterministicBrainProvider().insight(.init(trendWeight: nil, momentum: nil, readiness: nil, calories: nil,
            protein: nil, confidence: .low, observedWeightDays: 0, allowedActions: RecommendedAction.allCases))
        try ExerciseCatalog.seed(in: modelContext)
        try refresh(at: now)
    }

    func refresh(at date: Date = .now) throws {
        now = date
        try loadRecords()
        materializeToday()
        synchronizeToday()
        try finalizeClosedDays()
        try loadRecords()
        deriveState()
        try context.save()
        revision += 1
        scheduleAnalysis()
    }

    func refreshSafely() {
        do { try refresh(at: currentDate()) } catch { recover(from: error) }
    }

    func perform(_ change: () throws -> Void) -> Bool {
        do { now = currentDate(); try refresh(at: now); try change(); try refresh(at: now); return true }
        catch { recover(from: error); return false }
    }
    private func recover(from error: Error) {
        context.rollback()
        errorMessage = error.localizedDescription
        do { try loadRecords(); deriveState(); revision += 1 } catch { errorMessage = error.localizedDescription }
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
        for occurrence in todayObjectives where !occurrence.recoveryExempt {
            let kind = ObjectiveKind(rawValue: occurrence.kindRaw) ?? .custom
            if kind == .exercise, let id = occurrence.objective?.exerciseCatalogID {
                occurrence.value = sessions.filter { policy.sameDay($0.startedAt, now) && $0.completedAt != nil }
                    .flatMap(\.exercises).filter { $0.exercise?.catalogID == id }.flatMap(\.sets)
                    .filter { !$0.isWarmup }.reduce(0) { $0 + Double($1.reps) }
            } else {
                occurrence.value = ObjectiveEngine().value(kind: kind, manual: occurrence.value,
                    calories: todayNutrition?.calories, protein: todayNutrition?.proteinGrams,
                    weighed: weights.contains { policy.sameDay($0.measuredAt, now) },
                    workedOut: sessions.contains { policy.sameDay($0.startedAt, now) && $0.completedAt != nil })
            }
            occurrence.completedAt = occurrence.value >= occurrence.target ? occurrence.completedAt ?? now : nil
        }
    }

    private func deriveState() {
        let weightSamples = weights.map { WeightSample(date: $0.measuredAt, kilograms: $0.kilograms) }
        let nutritionSamples = nutrition.map { NutritionSample(date: $0.date, calories: $0.calories, protein: $0.proteinGrams) }
        let sleepSamples = sleep.map { SleepSample(date: $0.date, hours: $0.durationHours, quality: $0.quality) }
        progress = ProgressEngine().report(samples: weightSamples, start: profile.startingWeightKG, target: profile.targetWeightKG,
            desiredWeeklyChange: profile.desiredWeeklyChangeKG, now: now, policy: policy)
        personalModel = PersonalModel(weights: weightSamples, nutrition: nutritionSamples, sleep: sleepSamples,
            workoutDates: sessions.filter { $0.completedAt != nil }.map(\.startedAt), now: now, policy: policy)
        let recentStart = policy.adding(days: -2, to: policy.start(of: now))
        let recentNutrition = nutrition.filter { $0.date >= recentStart && $0.date <= now }
        let recentSleep = sleep.last { $0.date <= now && $0.date >= policy.adding(days: -1, to: policy.start(of: now)) }
        let context = RecoveryContext(sleepHours: recentSleep?.durationHours, sleepQuality: recentSleep?.quality,
            sleepTarget: profile.sleepTargetHours,
            calorieAdherence: FitnessMath.average(recentNutrition.map { $0.calories / max(1, $0.calorieGoal) }),
            proteinAdherence: FitnessMath.average(recentNutrition.map { $0.proteinGrams / max(1, $0.proteinGoal) }),
            tolerance: personalModel.recoveryTolerance,
            historyDays: personalModel.windows.last?.trainingDays ?? 0)
        let loads = sessions.filter { $0.completedAt != nil }.flatMap { session in
            session.exercises.map { exercise in
                let sets = exercise.sets.filter { !$0.isWarmup }
                let exertion = FitnessMath.average(sets.compactMap(\.perceivedExertion)) ?? 7
                return TrainingLoad(date: session.startedAt, contributions: exercise.contributions,
                    challengingSets: WorkoutEngine().load(sets: sets.map(\.performance), mode: exercise.trackingMode, quick: session.isQuickLog),
                    intensity: exertion / 8)
            }
        }
        readiness = RecoveryEngine().evaluate(loads: loads, context: context, now: now)
        projectedScore = ELOEngine().evaluate(evaluationInput(for: now, includeMisses: false), previousELO: currentELO)
        let value = brainContext()
        if !settings.onDeviceAIEnabled || lastAnalyzedContext != Self.encodeContext(value) || insight.source != .onDevice {
            insight = DeterministicBrainProvider().insight(value)
        }
    }

    func report(window: EvaluationWindow) -> ProgressReport {
        ProgressEngine().report(samples: weights.map { .init(date: $0.measuredAt, kilograms: $0.kilograms) },
            start: profile.startingWeightKG, target: profile.targetWeightKG, desiredWeeklyChange: profile.desiredWeeklyChangeKG,
            window: window, now: now, policy: policy)
    }

    private func brainContext() -> BrainContext {
        BrainContext(trendWeight: progress.trendWeight, momentum: progress.momentumPercent, readiness: readiness.percent,
            calories: todayNutrition?.calories, protein: todayNutrition?.proteinGrams, confidence: progress.confidence,
            observedWeightDays: personalModel.windows.first(where: { $0.days == 28 })?.observedWeightDays ?? 0,
            allowedActions: RecommendedAction.allCases)
    }
    private static func encodeContext(_ value: BrainContext) -> Data? {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(value)
    }
    private func scheduleAnalysis() {
        let value = brainContext()
        guard let encoded = Self.encodeContext(value) else { return }
        guard settings.onDeviceAIEnabled else {
            analysisTask?.cancel(); analysisTask = nil; lastAnalyzedContext = nil
            return
        }
        let retryDue = insight.source == .deterministic && now.timeIntervalSince(lastAnalysisAt ?? .distantPast) >= 900
        guard lastAnalyzedContext != encoded || (analysisTask == nil && retryDue) else { return }
        lastAnalyzedContext = encoded; lastAnalysisAt = now
        analysisTask?.cancel()
        let provider: (any BrainProvider)?
        #if canImport(FoundationModels)
        provider = FoundationModelsBrainProvider()
        #else
        provider = nil
        #endif
        analysisTask = Task { [weak self] in
            let result = await FitnessBrain(provider: provider).analyze(value)
            guard !Task.isCancelled, let self, self.settings.onDeviceAIEnabled, self.lastAnalyzedContext == encoded else { return }
            self.analysisTask = nil
            self.insight = result
            if result.source == .onDevice {
                do {
                    let record = try BrainInsightRecord(insight: result, createdAt: self.now, contextFingerprint: encoded.base64EncodedString())
                    self.context.insert(record)
                    try self.context.save()
                } catch { self.context.rollback(); self.errorMessage = error.localizedDescription }
            }
        }
    }
}
