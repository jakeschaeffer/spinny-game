import XCTest

/// Drives the Apple TV app with the Siri Remote's buttons. The remote's touch surface can't be scripted,
/// so "touch to latch" itself still needs trying on a real Apple TV; these cover clicks, focus and pausing,
/// which reach the game by the same route (`RemoteWindow`).
final class RemoteTests: XCTestCase {
    private let app = XCUIApplication()
    private let remote = XCUIRemote.shared

    override func setUp() {
        continueAfterFailure = false
        // Skip Game Center's sign-in screen and the first-launch detour into the lesson.
        app.launchArguments = ["-noGameCenter", "-oneMoreLine.lessonSeen", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["LAUNCH"].waitForExistence(timeout: 10))
    }

    func testTheMenuStartsOnLaunchAndFocusFollowsTheRemote() {
        XCTAssertTrue(waitForFocus(on: "LAUNCH"))
        remote.press(.down)
        XCTAssertTrue(waitForFocus(on: "LEARN TO FLY"))
        remote.press(.up)
        XCTAssertTrue(waitForFocus(on: "LAUNCH"))
    }

    func testPlayPauseAndBackPauseARunInsteadOfLeavingTheApp() {
        XCTAssertTrue(waitForFocus(on: "LAUNCH"))
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["PAUSE"].waitForExistence(timeout: 5), "the run's HUD should be up")

        remote.press(.playPause)
        XCTAssertTrue(app.staticTexts["PAUSED"].waitForExistence(timeout: 3))
        XCTAssertTrue(waitForFocus(on: "RESUME"), "the pause card should take focus")

        // Back on the pause card resumes rather than quitting.
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["PAUSED"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningForeground)

        // Back during the run pauses too.
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["PAUSED"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningForeground)

        remote.press(.down)
        remote.press(.down)
        remote.press(.down)
        XCTAssertTrue(waitForFocus(on: "MENU"))
        remote.press(.select)
        XCTAssertTrue(app.buttons["LAUNCH"].waitForExistence(timeout: 3))
    }

    /// The lesson's tips only move on when the comet really latches and launches, so they show whether a
    /// held click reached the game.
    func testHoldingAClickLatchesAndLettingGoLaunches() {
        XCTAssertTrue(waitForFocus(on: "LAUNCH"))
        remote.press(.down)
        XCTAssertTrue(waitForFocus(on: "LEARN TO FLY"))
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["TOUCH TO LATCH"].waitForExistence(timeout: 5))

        let launched = app.staticTexts.matching(NSPredicate(format: "label IN %@", [
            "LATCH THE NEXT ONE", "BUMPERS ARE ON", "MIND THE WALLS", "CLIMB TO 150",
        ]))
        for _ in 0..<40 where launched.count == 0 {
            if app.buttons["TRY AGAIN"].exists {
                remote.press(.select)
            } else {
                remote.press(.select, forDuration: 0.6)
            }
            usleep(250_000)
        }
        XCTAssertGreaterThan(launched.count, 0, "holding and releasing a click should latch and launch")
    }

    func testSettingsOpenAndANumberChangesWithLeftAndRight() {
        for _ in 0..<4 { remote.press(.down) }
        XCTAssertTrue(waitForFocus(on: "SETTINGS"))
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["SETTINGS"].waitForExistence(timeout: 3))

        let spin = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Spin speed'")).firstMatch
        for _ in 0..<12 where !spin.hasFocus { remote.press(.down) }
        XCTAssertTrue(spin.hasFocus)
        XCTAssertEqual(spin.value as? String, "1.00×")
        remote.press(.right)
        XCTAssertEqual(spin.value as? String, "1.05×")
        remote.press(.left)
        XCTAssertEqual(spin.value as? String, "1.00×")

        remote.press(.menu)
        XCTAssertTrue(app.buttons["LAUNCH"].waitForExistence(timeout: 3))
    }

    private func waitForFocus(on title: String) -> Bool {
        let button = app.buttons[title]
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasFocus == true"), object: button)
        return XCTWaiter().wait(for: [focused], timeout: 5) == .completed
    }
}
