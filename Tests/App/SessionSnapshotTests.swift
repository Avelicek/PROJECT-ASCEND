import XCTest
@testable import ASCEND

final class SessionSnapshotTests: XCTestCase {
    @MainActor func testWarmupsAndTimedEntriesDoNotInventLoadedVolumeOrFocus() {
        let exercise = Exercise(catalogID: "snapshot", name: "Press", category: .strength,
            equipment: .barbell, trackingMode: .weightAndReps, bodyweightCapable: false,
            additionalWeightAllowed: false, contributions: [.init(.upperPectoral, 0.7), .init(.anteriorDeltoid, 0.3)])
        let session = WorkoutSession(startedAt: Date(), title: "Snapshot", isQuickLog: true)
        let entry = WorkoutExercise(exercise: exercise, order: 0)
        let working = WorkoutSet(order: 0, performance: .init(reps: 10, kilograms: 50), completedAt: Date(), perceivedExertion: 8)
        let warmup = WorkoutSet(order: 1, performance: .init(reps: 20, kilograms: 20), completedAt: Date(), perceivedExertion: 3)
        warmup.isWarmup = true
        entry.sets = [working, warmup]
        session.exercises = [entry]
        let snapshot = SessionSnapshot(session: session)
        XCTAssertEqual(snapshot.workingSets, 1)
        XCTAssertEqual(snapshot.warmupSets, 1)
        XCTAssertEqual(snapshot.volumeKG, 500)
        XCTAssertEqual(snapshot.exertion, 8)
        XCTAssertEqual(snapshot.focus.first?.group, "Chest")
        XCTAssertEqual(snapshot.focus.first?.share ?? 0, 0.7, accuracy: 0.0001)
        entry.trackingModeRaw = TrackingMode.duration.rawValue
        XCTAssertEqual(SessionSnapshot(session: session).volumeKG, 0)
        entry.sets = [warmup]
        XCTAssertTrue(SessionSnapshot(session: session).focus.isEmpty)
        XCTAssertNil(SessionSnapshot(session: session).exertion)
    }
}
