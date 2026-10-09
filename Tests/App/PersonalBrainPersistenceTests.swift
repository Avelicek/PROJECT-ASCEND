import Foundation
import XCTest
@testable import ASCEND

final class PersonalBrainPersistenceTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_791_288_000)
    @MainActor private func store(storage: BrainStorage? = nil) throws -> AppStore {
        let fixed = date
        return try AppStore(container: PersistenceController.makeContainer(inMemory: true), now: fixed, clock: { fixed }, brainStorage: storage)
    }
    @MainActor func testSettingsAndExplicitResponseSurviveRecreation() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("brain-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = BrainStorage(url: url), first = try store(storage: storage)
        first.editBrainSettings { $0.duration = .short; $0.useNutrition = false }
        first.respondToBrain(.ignored)
        let restored = try store(storage: storage)
        XCTAssertEqual(restored.brainArchive.settings.duration, .short)
        XCTAssertFalse(restored.brainArchive.settings.useNutrition)
        XCTAssertTrue(restored.brainArchive.history.contains { $0.response == .ignored })
        XCTAssertTrue(restored.sessions.isEmpty)
    }
    @MainActor func testCorruptArchiveIsPreservedAndCannotBeOverwritten() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("brain-bad-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = Data("{\"version\":999,\"settings\":{},\"history\":[],\"preferences\":[]}".utf8)
        try data.write(to: url)
        let value = try store(storage: .init(url: url))
        XCTAssertTrue(value.brainStorageUnavailable)
        value.editBrainSettings { $0.enabled = false }
        XCTAssertEqual(try Data(contentsOf: url), data)
        XCTAssertTrue(value.brainArchive.settings.enabled)
    }
    @MainActor func testFailedWriteRetainsCurrentSettings() throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("brain.json")
        let value = try store(storage: .init(url: missing))
        value.editBrainSettings { $0.enabled = false }
        XCTAssertTrue(value.brainArchive.settings.enabled)
        XCTAssertNotNil(value.errorMessage)
    }
    @MainActor func testGeneratedSessionDoesNotCreateSavedRoutineOrOverwriteDraft() throws {
        let value = try store()
        XCTAssertTrue(value.editTraining { $0.routines = [] })
        XCTAssertNotNil(value.brainDecision.session)
        value.startBrainSession()
        let draft = try XCTUnwrap(value.activeWorkout)
        XCTAssertNil(draft.routineID); XCTAssertTrue(value.training.routines.isEmpty)
        XCTAssertFalse(draft.exercises.isEmpty)
        XCTAssertTrue(value.brainArchive.history.contains { $0.response == .accepted })
        value.startBrainSession()
        XCTAssertEqual(value.activeWorkout?.id, draft.id)
    }
    @MainActor func testCanonicalDemoSupportsPullAndContextRefreshChangesDecision() throws {
        let fixed = date
        let value = try AppStore(container: PersistenceController.makeContainer(inMemory: true), demo: true, now: fixed, clock: { fixed })
        XCTAssertNotNil(value.brainDecision.session)
        XCTAssertNil(value.brainDecision.routineID)
        XCTAssertTrue([RecommendationAction.train, .trainLight].contains(value.brainDecision.action))
        XCTAssertTrue(value.personalContext.sessionDates.count >= 3)
        XCTAssertTrue(value.perform { value.todaySleep?.durationHours = 3; value.todaySleep?.quality = 1 })
        XCTAssertEqual(value.brainDecision.action, .recover)
        value.editBrainSettings { $0.useSleep = false }
        XCTAssertNotEqual(value.brainDecision.action, .recover)
    }
    @MainActor func testChangingEquipmentInvalidatesCachedRecommendation() throws {
        let fixed = date
        let value = try AppStore(container: PersistenceController.makeContainer(inMemory: true), demo: true, now: fixed, clock: { fixed })
        let old = value.brainDecision.id
        XCTAssertTrue(value.editTraining { $0.profile.equipment = [.bodyweight] })
        XCTAssertNotEqual(value.brainDecision.id, old)
        for item in value.brainDecision.session?.exercises ?? [] { XCTAssertTrue(value.missingEquipment(item.exerciseID).isEmpty) }
    }
}
