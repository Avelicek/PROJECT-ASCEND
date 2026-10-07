import Foundation
import SwiftData

enum PreviewData {
    #if DEBUG
    @MainActor static func preparePresentationFixture(store: AppStore, arguments: [String] = ProcessInfo.processInfo.arguments) throws {
        guard store.isDemo, arguments.contains("--ui-testing") else { return }
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
        for (id, kg) in [("bench_press", 57.5), ("seated_row", 40.0), ("overhead_press", 35.0), ("lateral_raise", 8.0)] {
            guard let catalog = store.exercises.first(where: { $0.catalogID == id }) else { continue }
            store.addLiveExercise(catalog)
            guard let exercise = store.activeWorkout?.exercises.last else { continue }
            for _ in 0..<(id == "bench_press" ? 3 : 2) { store.addLiveSet(exerciseID: exercise.id) }
            store.changeLiveExercise(exercise.id) { entry in
                for index in entry.sets.indices {
                    entry.sets[index].kilograms = kg; entry.sets[index].reps = index == 0 ? 9 : 8; entry.sets[index].rpe = 7.5
                    if summary || (id == "bench_press" && index < 2) { entry.sets[index].completedAt = store.now }
                }
            }
        }
        _ = store.updateWorkout { draft in
            let firstExerciseID = draft?.exercises.first?.id
            draft?.selectedExerciseID = firstExerciseID
            draft?.rest.start(seconds: 90, exerciseID: "bench_press", at: .now)
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
            if offset % 3 == 1, let exercise = catalog.first(where: { $0.catalogID == "bench_press" }) {
                let session = WorkoutSession(startedAt: date.addingTimeInterval(17 * 3600), title: "Upper body", isQuickLog: false)
                session.completedAt = session.startedAt
                let entry = WorkoutExercise(exercise: exercise, order: 0); entry.session = session; session.exercises.append(entry)
                for index in 0..<3 {
                    let set = WorkoutSet(order: index, performance: .init(reps: 8 - index, kilograms: 55), completedAt: session.startedAt)
                    set.workoutExercise = entry; entry.sets.append(set)
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
