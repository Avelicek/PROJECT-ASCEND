import XCTest

final class PersonalTrainingSmokeTests: XCTestCase {
    @MainActor func testEquipmentProfileAndLibraryFavorites() {
        continueAfterFailure = false
        let app = AscendUITestSupport.launchDemo()
        AscendUITestSupport.navigate("profile", in: app)
        let profile = app.scrollViews["screen.profile"]
        let gym = app.buttons["profile.training"]
        for _ in 0..<6 { if gym.isHittable && gym.frame.maxY < app.buttons["tab.profile"].frame.minY - 12 { break }; profile.swipeUp() }
        XCTAssertTrue(gym.isHittable); gym.tap()
        XCTAssertTrue(app.scrollViews["screen.trainingprofile"].waitForExistence(timeout: 10))
        let dumbbells = app.buttons["gym.equipment.dumbbells"]
        XCTAssertTrue(dumbbells.waitForExistence(timeout: 10)); XCTAssertEqual(dumbbells.value as? String, "Available")
        dumbbells.tap(); XCTAssertEqual(dumbbells.value as? String, "Not available")
        dumbbells.tap(); XCTAssertEqual(dumbbells.value as? String, "Available")
        app.buttons["Done"].tap()
        AscendUITestSupport.navigate("workout", in: app)
        let library = app.buttons["workout.library"]
        for _ in 0..<6 { if library.isHittable && library.frame.maxY < app.buttons["tab.workout"].frame.minY - 12 { break }; app.scrollViews["screen.workout"].swipeUp() }
        XCTAssertTrue(library.isHittable); library.tap()
        let search = app.textFields["library.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap(); search.typeText("One-arm dumbbell row")
        let row = app.buttons["live.choose.db_row"]
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        XCTAssertTrue(app.scrollViews["screen.exercisehistory"].waitForExistence(timeout: 10))
        let favorite = app.buttons["exercise.favorite"]
        XCTAssertEqual(favorite.label, "Favorited"); favorite.tap(); XCTAssertEqual(favorite.label, "Favorite")
        app.terminate()
    }
    @MainActor func testRoutineReplacementAndFastBodyweightLogging() {
        continueAfterFailure = false
        let app = AscendUITestSupport.launchDemo()
        AscendUITestSupport.navigate("workout", in: app)
        let routine = app.buttons["workout.routine.Bodyweight push"]
        for _ in 0..<8 { if routine.isHittable && routine.frame.maxY < app.buttons["tab.workout"].frame.minY - 12 { break }; app.scrollViews["screen.workout"].swipeUp() }
        XCTAssertTrue(routine.isHittable); routine.tap()
        XCTAssertTrue(app.buttons["routine.start"].waitForExistence(timeout: 10)); app.buttons["routine.start"].tap()
        let live = app.scrollViews["screen.liveworkout"]
        XCTAssertTrue(live.waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["live.title"].exists)
        let add = app.buttons["live.add.exercise"]
        add.tap()
        let search = app.textFields["library.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap(); search.typeText("Reverse crunch")
        let crunch = app.buttons["live.choose.reverse_crunch"]
        XCTAssertTrue(crunch.waitForExistence(timeout: 10)); crunch.tap()
        let replace = app.buttons["live.replace"]
        for _ in 0..<8 { if replace.isHittable { break }; live.swipeUp() }
        XCTAssertTrue(replace.isHittable); replace.tap()
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.tap(); search.typeText("Lying leg raise")
        let legRaise = app.buttons["live.choose.leg_raise"]
        XCTAssertTrue(legRaise.waitForExistence(timeout: 10)); legRaise.tap()
        let reps = app.textFields["live.set.reps"].firstMatch
        for _ in 0..<8 { if reps.isHittable { break }; live.swipeDown() }
        XCTAssertTrue(reps.isHittable); XCTAssertEqual(app.textFields["live.set.kg"].count, 0)
        reps.tap(); let old = reps.value as? String ?? ""
        reps.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + "20")
        let complete = app.buttons["live.keyboard.complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 10)); complete.tap()
        XCTAssertTrue(app.buttons["live.rest.pause"].waitForExistence(timeout: 10))
        XCTAssertEqual(reps.value as? String, "20"); XCTAssertFalse(reps.isEnabled)
        app.terminate()
    }
}
