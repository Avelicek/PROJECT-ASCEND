import Foundation
import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class RecoveryEngineTests: XCTestCase {
    func testNoInputDoesNotInventReadiness() {
        let result = RecoveryEngine().evaluate(loads: [], context: .init(), now: .now)
        XCTAssertNil(result.percent); XCTAssertNil(result.state); XCTAssertEqual(result.confidence, .low)
    }
    func testNutritionAloneDoesNotInventBodyReadiness() {
        let result = RecoveryEngine().evaluate(loads: [], context: .init(calorieAdherence: 1, proteinAdherence: 1), now: .now)
        XCTAssertNil(result.percent); XCTAssertEqual(result.confidence, .low)
    }
    func testBoundsUnderExtremeLoadAndSupport() throws {
        let now = Date.now
        for support in [-100.0, 0, 8, 1_000] {
            let context = RecoveryContext(sleepHours: support, sleepQuality: Int(support), calorieAdherence: support, proteinAdherence: support)
            let loads = (0..<100).map { _ in TrainingLoad(date: now, contributions: [.init(.midPectoral, 1)], challengingSets: 10_000, intensity: 50) }
            let result = RecoveryEngine().evaluate(loads: loads, context: context, now: now)
            XCTAssertTrue((0...100).contains(try XCTUnwrap(result.percent)))
            for muscle in result.muscles {
                XCTAssertTrue((0...100).contains(muscle.recoveryPercent)); XCTAssertTrue((0...100).contains(muscle.fatigue))
            }
        }
    }
    func testLoadDecaysAndOverlappingSessionsAccumulate() throws {
        let now = Date.now
        let recent = TrainingLoad(date: now, contributions: [.init(.midPectoral, 1)], challengingSets: 4, intensity: 1)
        let older = TrainingLoad(date: now.addingTimeInterval(-48 * 3600), contributions: [.init(.midPectoral, 1)], challengingSets: 4, intensity: 1)
        let engine = RecoveryEngine()
        let one = engine.evaluate(loads: [recent], context: .init(), now: now).muscles.first { $0.muscle == .midPectoral }
        let decayed = engine.evaluate(loads: [older], context: .init(), now: now).muscles.first { $0.muscle == .midPectoral }
        let accumulated = engine.evaluate(loads: [older, recent], context: .init(), now: now).muscles.first { $0.muscle == .midPectoral }
        XCTAssertGreaterThan(try XCTUnwrap(decayed).recoveryPercent, try XCTUnwrap(one).recoveryPercent)
        XCTAssertLessThan(try XCTUnwrap(accumulated).recoveryPercent, try XCTUnwrap(one).recoveryPercent)
    }
    func testFutureTrainingIsIgnored() {
        let now = Date.now
        let load = TrainingLoad(date: now.addingTimeInterval(3600), contributions: [.init(.midPectoral, 1)], challengingSets: 10, intensity: 1)
        XCTAssertNil(RecoveryEngine().evaluate(loads: [load], context: .init(), now: now).percent)
    }
    func testPoorSleepChangesReadiness() throws {
        let engine = RecoveryEngine()
        let good = engine.evaluate(loads: [], context: .init(sleepHours: 8, sleepQuality: 5), now: .now)
        let poor = engine.evaluate(loads: [], context: .init(sleepHours: 3, sleepQuality: 1), now: .now)
        XCTAssertGreaterThan(try XCTUnwrap(good.percent), try XCTUnwrap(poor.percent))
    }
}
