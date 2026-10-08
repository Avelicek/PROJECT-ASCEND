import Foundation
import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class OwnerSystemTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_288_000)
    func testSleepIntervalCrossesMidnightAndDaylightSavingWithoutTimer() throws {
        let start = now.addingTimeInterval(-7 * 3600 - 47 * 60)
        XCTAssertEqual(try RecordedSleep.hours(start: start, end: now, now: now), 7 + 47.0 / 60, accuracy: 0.0001)
        var state = OwnerSystem(); state.sleepStartedAt = start
        let reopened = try JSONDecoder().decode(OwnerSystem.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(reopened.sleepStartedAt, start)
        let policy = DayPolicy(timeZoneIdentifier: "Europe/Prague")
        let formatter = ISO8601DateFormatter()
        let dstStart = try XCTUnwrap(formatter.date(from: "2026-10-24T23:00:00+02:00"))
        let dstEnd = try XCTUnwrap(formatter.date(from: "2026-10-25T07:00:00+01:00"))
        XCTAssertEqual(try RecordedSleep.hours(start: dstStart, end: dstEnd, now: dstEnd), 9)
        XCTAssertEqual(policy.key(for: dstStart), "2026-10-24")
        XCTAssertEqual(policy.key(for: dstEnd), "2026-10-25")
    }
    func testAccidentalImmediateLongAndFutureIntervalsAreRejected() {
        for (start, end) in [(now, now), (now, now.addingTimeInterval(-60)), (now.addingTimeInterval(-25 * 3600), now), (now.addingTimeInterval(-3600), now.addingTimeInterval(1))] {
            XCTAssertThrowsError(try RecordedSleep.hours(start: start, end: end, now: now))
        }
    }
    func testResetRequiresBothExactPhraseAndConsent() {
        XCTAssertFalse(ResetConsent.allowed(checked: false, phrase: "RESET ASCEND"))
        XCTAssertFalse(ResetConsent.allowed(checked: true, phrase: "reset ascend"))
        XCTAssertFalse(ResetConsent.allowed(checked: true, phrase: "RESET ASCEND "))
        XCTAssertTrue(ResetConsent.allowed(checked: true, phrase: "RESET ASCEND"))
    }
    func testSickProtectionSurvivesEndAndDoesNotProtectFutureDays() throws {
        let policy = DayPolicy(timeZoneIdentifier: "UTC")
        var state = OwnerSystem(); state.sickIntervals = [.init(start: now)]
        XCTAssertTrue(state.sickActive)
        state.sickIntervals[0].end = now.addingTimeInterval(3600)
        XCTAssertFalse(state.sickActive)
        XCTAssertTrue(state.protectsTraining(on: now, policy: policy))
        XCTAssertFalse(state.protectsTraining(on: now.addingTimeInterval(86400), policy: policy))
        let reopened = try JSONDecoder().decode(OwnerSystem.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(reopened.sickIntervals.first?.end, state.sickIntervals.first?.end)
    }
    func testProtectedObjectiveCannotLoseOrEarnELO() {
        var input = ELOInput(); input.objectives = [.init(title: "100 push-ups", completed: false, importance: .major, recoveryExempt: true)]
        let result = ELOEngine().evaluate(input, previousELO: 100)
        XCTAssertEqual(result.delta, 0); XCTAssertTrue(result.components.isEmpty)
        input.proteinAdherence = 1
        XCTAssertEqual(ELOEngine().evaluate(input, previousELO: 100).delta, 3)
    }
    func testProtectedDaysBridgeStreakWithoutCreatingCompletion() {
        let policy = DayPolicy(timeZoneIdentifier: "UTC"), prior = now.addingTimeInterval(-2 * 86400), protected = now.addingTimeInterval(-86400)
        XCTAssertEqual(StreakEngine().daily(qualifyingDays: [prior], now: now, policy: policy), 0)
        XCTAssertEqual(StreakEngine().daily(qualifyingDays: [prior], now: now, policy: policy, protectedDays: [protected]), 1)
        XCTAssertEqual(StreakEngine().daily(qualifyingDays: [], now: now, policy: policy, protectedDays: [protected, now]), 0)
    }
    func testMeasurementValidationRejectsInvalidNumbersAndVersion() throws {
        var state = OwnerSystem(); state.measurements = [.init(date: now, waist: 75)]
        XCTAssertNoThrow(try state.validate())
        state.measurements = [.init(date: now, waist: .infinity)]
        XCTAssertThrowsError(try state.validate()); state.measurements = []; state.version = 2
        XCTAssertThrowsError(try state.validate())
    }
    func testEveryMajorLogicalMuscleHasARealNamedMesh() {
        let mapped = Set(AnatomyMeshMapping.muscles.values.flatMap { $0 }.map(\.rawValue))
        let required: [Muscle] = [.upperPectoral, .midPectoral, .lowerPectoral, .latissimus, .rhomboids, .upperTrapezius, .middleTrapezius, .lowerTrapezius, .anteriorDeltoid, .lateralDeltoid, .posteriorDeltoid, .bicepsLongHead, .tricepsLongHead, .forearmFlexors, .forearmExtensors, .rectusAbdominis, .obliques, .spinalErectors, .gluteusMaximus, .rectusFemoris, .vastusLateralis, .bicepsFemoris, .semitendinosus, .gastrocnemius, .soleus]
        for muscle in required {
            XCTAssertTrue(mapped.contains(muscle.rawValue), "Missing real mesh mapping: \(muscle)")
        }
        XCTAssertTrue(AnatomyMeshMapping.muscles.keys.allSatisfy { AnatomyMeshMapping.sourceNames[$0] != nil })
    }
}
