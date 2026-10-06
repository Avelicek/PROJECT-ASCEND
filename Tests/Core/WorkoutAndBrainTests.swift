import Foundation
import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class WorkoutAndBrainTests: XCTestCase {
    func testVolumeAndRecordDetection() {
        let sets = [SetPerformance(reps: 8, kilograms: 55), .init(reps: 8, kilograms: 55), .init(reps: 6, kilograms: 55)]
        let engine = WorkoutEngine()
        XCTAssertEqual(engine.volume(sets), 1210)
        let records = engine.newRecords(sets: sets, previous: [.weight: 60, .reps: 7, .volume: 1000, .estimatedOneRepMax: 80])
        XCTAssertEqual(Set(records.map(\.kind)), Set([.reps, .volume]))
    }
    func testBodyweightDoesNotInventLoadedOneRepMax() {
        let candidates = WorkoutEngine().recordCandidates([.init(reps: 50)])
        XCTAssertEqual(candidates.count, 1); XCTAssertEqual(candidates.first?.kind, .reps)
    }
    func testSparseDataKeepsPersonalConfidenceLow() {
        let now = Date.now
        let model = PersonalModel(weights: [.init(date: now, kilograms: 56)], nutrition: [], sleep: [], workoutDates: [], now: now, policy: .init())
        XCTAssertTrue(model.windows.allSatisfy { $0.confidence == .low }); XCTAssertEqual(model.recoveryTolerance, 1)
    }
    @MainActor func testFallbackWorksWhenProviderThrows() async {
        struct Unavailable: BrainProvider {
            struct Failure: Error {}
            func analyze(_ context: BrainContext) async throws -> BrainInsight { throw Failure() }
        }
        let context = BrainContext(trendWeight: nil, momentum: nil, readiness: nil, calories: nil, protein: nil,
            confidence: .low, observedWeightDays: 0, allowedActions: [.logWeight])
        let result = await FitnessBrain(provider: Unavailable()).analyze(context)
        XCTAssertEqual(result.source, .deterministic); XCTAssertEqual(result.confidence, .low)
        XCTAssertEqual(result.recommendations.first?.action, .logWeight)
    }
    func testFallbackOnlyOffersAllowedActions() {
        let context = BrainContext(trendWeight: nil, momentum: nil, readiness: nil, calories: nil, protein: nil,
            confidence: .low, observedWeightDays: 0, allowedActions: [])
        XCTAssertTrue(DeterministicBrainProvider().insight(context).recommendations.isEmpty)
    }
    @MainActor func testMissingProviderReturnsTheCompleteDeterministicInsight() async {
        let context = BrainContext(trendWeight: 56, momentum: 2, readiness: 80, calories: 2800, protein: 120,
            confidence: .medium, observedWeightDays: 14, allowedActions: [.logWeight])
        let expected = DeterministicBrainProvider().insight(context)
        let actual = await FitnessBrain().analyze(context)
        XCTAssertEqual(actual.source, .deterministic)
        XCTAssertEqual(actual.headline, expected.headline)
        XCTAssertEqual(actual.summary, expected.summary)
        XCTAssertEqual(actual.confidence, expected.confidence)
        XCTAssertEqual(actual.recommendations.map(\.action), expected.recommendations.map(\.action))
    }
}
