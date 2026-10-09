import Foundation
import SwiftData

enum PreviewData {
    #if DEBUG
    @MainActor static func preparePresentationFixture(store: AppStore, arguments: [String] = ProcessInfo.processInfo.arguments) throws {
        guard store.isDemo, arguments.contains("--ui-testing") else { return }
        if arguments.contains("--capture-sleep-summary") { store.presentedSheet = .sleepSummary }
        if arguments.contains("--capture-goal-coach") { store.presentedSheet = .goalCoach }
        if arguments.contains("--capture-checkin") { store.presentedSheet = .checkIn }
        if arguments.contains("--capture-ask") { store.presentedSheet = .ask }
        if arguments.contains("--capture-weekly") { store.presentedSheet = .weekly }
        if arguments.contains("--capture-timer"), let plank = store.exercises.first(where: { $0.catalogID == "plank" }) {
            store.startLiveWorkout(); store.addLiveExercise(plank)
            if let exercise = store.activeWorkout?.exercises.first { store.startExerciseClock(exerciseID: exercise.id, setID: exercise.sets[0].id); store.pauseExerciseClock() }
        }
        if arguments.contains("--capture-onboarding") { store.ownerSystem.onboardingComplete = false }
        if arguments.contains("--capture-sleep") || arguments.contains("--capture-end-sleep") {
            store.ownerSystem.sleepStartedAt = store.now.addingTimeInterval(-8 * 3600)
            if arguments.contains("--capture-end-sleep") { store.ownerSystem.sleepEndedAt = store.now }
            try store.refresh(at: store.now)
        }
        if arguments.contains("--capture-sick") { store.startSick(note: "Training pause") }
        if arguments.contains("--capture-objectives") {
            var objective = ObjectiveDraft(); objective.title = "100 push-ups"; objective.kind = .exercise; objective.target = 100; objective.unit = "reps"; objective.exerciseCatalogID = "push_up"; objective.startsAt = store.now
            _ = store.saveObjective(objective)
            if let exercise = store.exercises.first(where: { $0.catalogID == "push_up" }) { _ = store.logWorkout(exercise: exercise, sets: [.init(reps: 60)], at: store.now, quick: true, exertion: 7) }
            store.presentedSheet = .objectives
        }
        if arguments.contains("--brain-low-data") {
            for entry in store.sleep { store.context.delete(entry) }
            for entry in store.nutrition { store.context.delete(entry) }
            for entry in store.sessions { store.context.delete(entry) }
            try store.refresh(at: store.now)
        }
        if arguments.contains("--brain-poor-sleep"), let sleep = store.todaySleep {
            sleep.durationHours = 3; sleep.quality = 1
            try store.refresh(at: store.now)
        }
        if arguments.contains("--rank-reward"), let entry = store.history.last {
            entry.previousELO = 1195; entry.elo = 1208; entry.delta = 13
            entry.evaluation?.eloDelta = 13
            entry.evaluation?.componentData = try JSONEncoder().encode([
                ScoreComponent(category: .training, label: "Completed workout", points: 5),
                .init(category: .nutrition, label: "Nutrition goals", points: 6), .init(category: .objective, label: "Daily objective", points: 2)])
            try store.context.save()
        }
        guard arguments.contains("--capture-live") || arguments.contains("--capture-summary") else { return }
        let summary = arguments.contains("--capture-summary")
        _ = store.updateWorkout { $0 = LiveWorkout(startedAt: store.now.addingTimeInterval(summary ? -2778 : -2712), title: "Upper body") }
        for (id, kg) in [("lat_pulldown", 45.0), ("chest_press", 47.5), ("db_row", 22.0), ("lateral_raise", 8.0)] {
            guard let catalog = store.exercises.first(where: { $0.catalogID == id }) else { continue }
            store.addLiveExercise(catalog)
            guard let exercise = store.activeWorkout?.exercises.last else { continue }
            for _ in 0..<(id == "lat_pulldown" ? 3 : 2) { store.addLiveSet(exerciseID: exercise.id) }
            store.changeLiveExercise(exercise.id) { entry in
                for index in entry.sets.indices {
                    entry.sets[index].kilograms = kg; entry.sets[index].reps = index == 0 ? 9 : 8; entry.sets[index].rpe = 7.5
                    if summary || (id == "lat_pulldown" && index < 2) { entry.sets[index].completedAt = store.now }
                }
            }
        }
        _ = store.updateWorkout { draft in
            let firstExerciseID = draft?.exercises.first?.id
            draft?.selectedExerciseID = firstExerciseID
            draft?.rest.start(seconds: 90, exerciseID: "lat_pulldown", at: .now)
            draft?.rest.pause(at: .now); draft?.rest.pausedSeconds = 61
        }
        store.liveWorkoutPresented = true
        if summary { _ = store.finishLiveWorkout() }
    }
    #endif
    @MainActor static func makeStore() throws -> AppStore {
        try AppStore(container: PersistenceController.makeContainer(inMemory: true), demo: true)
    }
    @MainActor static func populate(context: ModelContext, now: Date) throws {
        guard try context.fetchCount(FetchDescriptor<UserProfile>()) == 0 else { return }
        let policy = DayPolicy()
        let user = UserProfile(displayName: "Alex", createdAt: policy.adding(days: -35, to: now))
        user.startingWeightKG = 54.2; user.targetWeightKG = 60; user.lifetimeCredits = 1380
        user.targetDeadline = policy.adding(days: 112, to: now)
        context.insert(user); context.insert(UserSettings())
        try ExerciseCatalog.seed(in: context)
        let catalog = try context.fetch(FetchDescriptor<Exercise>())
        for offset in stride(from: 34, through: 0, by: -1) {
            let date = policy.adding(days: -offset, to: policy.start(of: now))
            let kilograms = 55.5 + Double(34 - offset) * 0.028 + sin(Double(offset) * 1.7) * 0.14
            context.insert(BodyWeightEntry(measuredAt: date, kilograms: kilograms))
            context.insert(NutritionEntry(dayKey: policy.key(for: date), date: date,
                calories: offset == 0 ? 2240 : 2980 + Double(offset % 5) * 25,
                proteinGrams: offset == 0 ? 104 : 128 + Double(offset % 6), calorieGoal: 3000, proteinGoal: 130))
            context.insert(SleepEntry(dayKey: policy.key(for: date), date: date, durationHours: 7.5 + Double(offset % 3) * 0.2, quality: 4))
            if offset % 3 == 1 {
                let session = WorkoutSession(startedAt: date.addingTimeInterval(17 * 3600), title: "Upper body", isQuickLog: false)
                session.completedAt = session.startedAt
                let items: [(String, Double, Int)] = offset == 1 ? [("chest_press", 45, 10), ("push_up", 0, 18)] : [("lat_pulldown", 40, 10), ("db_row", 20, 10), ("pull_up", 0, 8), ("rear_delt_raise", 6, 12), ("hammer_curl", 8, 10)]
                session.title = offset == 1 ? "Push" : "Pull"
                for (order, item) in items.enumerated() {
                    guard let exercise = catalog.first(where: { $0.catalogID == item.0 }) else { continue }
                    let entry = WorkoutExercise(exercise: exercise, order: order); entry.session = session; session.exercises.append(entry)
                    for index in 0..<(offset == 1 && item.0 == "chest_press" ? 6 : 3) {
                        let set = WorkoutSet(order: index, performance: .init(reps: item.2 - index, kilograms: item.1), completedAt: session.startedAt, perceivedExertion: 7)
                        set.workoutExercise = entry; entry.sets.append(set)
                    }
                }
                context.insert(session)
            }
        }
        let yesterday = policy.adding(days: -1, to: policy.start(of: now))
        let components = [ScoreComponent(category: .training, label: "Completed workout", points: 5),
                          .init(category: .nutrition, label: "Nutrition goals", points: 6),
                          .init(category: .progress, label: "Weight trend", points: 3)]
        let result = ELOResult(previousELO: 1070, elo: 1084, delta: 14, components: components,
                              rank: RankEngine().status(elo: 1084, previousELO: 1070))
        let evaluation = try DailyEvaluation(dayKey: policy.key(for: yesterday), date: yesterday, result: result, evaluatedAt: now)
        let entry = ELOHistoryEntry(dayKey: evaluation.dayKey, date: yesterday, previousELO: 1070, elo: 1084, delta: 14)
        entry.evaluation = evaluation; evaluation.history = entry; context.insert(evaluation); context.insert(entry)
        for objective in [
            DailyObjective(title: "Hit your energy target", kind: .calories, cadence: .daily, importance: .major, target: 3000, unit: "kcal", startsAt: now),
            DailyObjective(title: "Protein, on point", kind: .protein, cadence: .daily, importance: .standard, target: 130, unit: "g", startsAt: now),
            DailyObjective(title: "Log body weight", kind: .bodyWeight, cadence: .daily, importance: .minor, target: 1, unit: "entry", startsAt: now),
            DailyObjective(title: "Take a mindful walk", kind: .custom, cadence: .daily, importance: .minor, target: 1, unit: "walk", startsAt: now)
        ] { context.insert(objective) }
        try context.save()
    }
}
