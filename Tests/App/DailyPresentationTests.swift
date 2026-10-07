import XCTest
@testable import ASCEND

final class DailyPresentationTests: XCTestCase {
    @MainActor func testNextActionPrioritizesResumingAndSupportedRecovery() throws {
        let store = try PreviewData.makeStore()
        XCTAssertEqual(store.nextAction.kind, .fuel)
        store.startLiveWorkout(); XCTAssertEqual(store.nextAction.kind, .resume)
        store.discardLiveWorkout()
        let load = TrainingLoad(date: store.now, contributions: [.init(.midPectoral, 1)], challengingSets: 12, intensity: 1)
        store.readiness = RecoveryEngine().evaluate(loads: [load], context: .init(), now: store.now)
        XCTAssertEqual(store.nextAction.kind, .fuel, "Low confidence cannot force a recovery action")
        store.readiness = RecoveryEngine().evaluate(loads: [load], context: .init(sleepHours: 8, sleepQuality: 4, calorieAdherence: 1, proteinAdherence: 1, historyDays: 28, trainingSessions: 6), now: store.now)
        XCTAssertEqual(store.nextAction.kind, .recover)
    }
    @MainActor func testAnatomyModesPreserveUnknownValues() {
        let report = RecoveryEngine().evaluate(loads: [], context: .init(), now: .now)
        let state = BodyRegion.chest.visualization(in: report)
        for mode in AnatomyMetricMode.allCases { XCTAssertNil(mode.value(state)) }
    }
    #if DEBUG
    @MainActor func testScreenshotFixturesAreMemoryOnlyAndCreateRealSummaryAndRankBoundary() throws {
        let date = Date(timeIntervalSince1970: 1_791_288_000)
        let store = try AppStore(container: PersistenceController.makeContainer(inMemory: true), demo: true, now: date, clock: { date })
        try PreviewData.preparePresentationFixture(store: store, arguments: ["--ui-testing", "--capture-summary"])
        let summary = try XCTUnwrap(store.completedWorkout)
        XCTAssertEqual(summary.durationSeconds, 2778); XCTAssertEqual(summary.exerciseCount, 4); XCTAssertEqual(summary.workingSets, 13)
        XCTAssertGreaterThan(summary.volumeKG, 0); XCTAssertFalse(summary.records.isEmpty)
        try PreviewData.preparePresentationFixture(store: store, arguments: ["--ui-testing", "--rank-reward"])
        let result = store.finalizedResult(try XCTUnwrap(store.history.last))
        XCTAssertEqual(result.elo.elo, 1208); XCTAssertTrue(result.elo.rank.rankedUp)
        XCTAssertNil(store.workoutStorage)
    }
    #endif
}
