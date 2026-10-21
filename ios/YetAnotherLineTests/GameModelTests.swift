import XCTest
@testable import YetAnotherLine

@MainActor
final class GameModelTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "GameModelTests")
        defaults.removePersistentDomain(forName: "GameModelTests")
        // Most tests are about normal runs; a brand-new player's first launch would go to the lesson.
        defaults.set(true, forKey: "oneMoreLine.lessonSeen")
    }

    private func finishRun(_ model: GameModel, in difficulty: Difficulty, score: Int, combo: Int) {
        model.difficulty = difficulty
        model.play()
        model.runEnded(score: score, bestCombo: combo, duration: 10)
    }

    func testAnOldBestCarriesOverAsTheAstroBest() {
        defaults.set(812, forKey: "oneMoreLine.best")
        let model = GameModel(defaults: defaults)
        XCTAssertEqual(model.difficulty, .astro, "Astro is the default mode")
        XCTAssertEqual(model.bests[.astro], 812)
        XCTAssertEqual(model.bests[.easy], 0)
    }

    func testEachModeKeepsItsOwnBestAndCombo() {
        let model = GameModel(defaults: defaults)
        finishRun(model, in: .easy, score: 300, combo: 4)
        XCTAssertEqual(model.lastRun?.isNewBest, true)
        XCTAssertEqual(model.lastRun?.isNewBestCombo, true)
        finishRun(model, in: .astro, score: 120, combo: 3)
        XCTAssertEqual(model.lastRun?.isNewBest, true, "Easy's 300 doesn't count against Astro")

        let reloaded = GameModel(defaults: defaults)
        XCTAssertEqual(reloaded.bests, [.easy: 300, .astro: 120])
        XCTAssertEqual(reloaded.bestCombos, [.easy: 4, .astro: 3])
        XCTAssertEqual(reloaded.difficulty, .astro, "the last picked mode is remembered")
    }

    func testBestComboOnlyCountsRealCombosAndBetterOnes() {
        let model = GameModel(defaults: defaults)
        finishRun(model, in: .astro, score: 50, combo: 1)
        XCTAssertEqual(model.lastRun?.isNewBestCombo, false, "×1 isn't a combo")
        finishRun(model, in: .astro, score: 40, combo: 5)
        XCTAssertEqual(model.lastRun?.isNewBestCombo, true)
        XCTAssertEqual(model.lastRun?.isNewBest, false)
        finishRun(model, in: .astro, score: 60, combo: 5)
        XCTAssertEqual(model.lastRun?.isNewBestCombo, false, "a tie isn't a new best")
        XCTAssertEqual(model.bestCombo, 5)
    }

    func testAModeChangeMidRunAppliesFromTheNextRun() {
        let model = GameModel(defaults: defaults)
        model.difficulty = .astro
        model.play()
        model.difficulty = .easy
        XCTAssertEqual(model.runDifficulty, .astro)
        model.runEnded(score: 77, bestCombo: 2, duration: 5)
        XCTAssertEqual(model.bests[.astro], 77)
        XCTAssertEqual(model.bests[.easy], 0)
    }

    func testResetClearsEveryModesBestsAndCombos() {
        let model = GameModel(defaults: defaults)
        finishRun(model, in: .easy, score: 300, combo: 4)
        finishRun(model, in: .astro, score: 120, combo: 3)
        model.resetBests()
        let reloaded = GameModel(defaults: defaults)
        XCTAssertEqual(reloaded.bests, [.easy: 0, .astro: 0])
        XCTAssertEqual(reloaded.bestCombos, [.easy: 0, .astro: 0])
    }

    // MARK: Lesson

    func testANewPlayersFirstLaunchStartsTheLessonOnlyOnce() {
        defaults.removeObject(forKey: "oneMoreLine.lessonSeen")
        let model = GameModel(defaults: defaults)
        model.play()
        XCTAssertNotNil(model.lesson)
        XCTAssertEqual(model.phase, .playing)
        model.goToMenu()
        model.play()
        XCTAssertNil(model.lesson, "the second launch is a normal run")
    }

    func testPlayersWithABestScoreSkipTheLesson() {
        defaults.removeObject(forKey: "oneMoreLine.lessonSeen")
        defaults.set(40, forKey: "oneMoreLine.best")
        let model = GameModel(defaults: defaults)
        model.play()
        XCTAssertNil(model.lesson)
    }

    func testALessonCrashExplainsAndRetriesWithoutTouchingBests() {
        let model = GameModel(defaults: defaults)
        model.startLesson()
        model.playerHooked()
        model.playerLaunched()
        model.scoreChanged(60)
        model.lessonCrashed(.wall)
        XCTAssertEqual(model.phase, .lessonOver)
        XCTAssertEqual(model.lessonOutcome, .crashed(.wall))
        XCTAssertEqual(model.bests, [.easy: 0, .astro: 0])

        model.retryLesson()
        XCTAssertEqual(model.phase, .playing)
        XCTAssertEqual(model.lesson?.step, .chain, "they'd already launched")
        XCTAssertEqual(model.score, 0)
    }

    func testRestartFromPauseReplaysTheLesson() {
        let model = GameModel(defaults: defaults)
        model.startLesson()
        model.pause()
        model.restart()
        XCTAssertNotNil(model.lesson)
        XCTAssertEqual(model.phase, .playing)
    }

    // MARK: Bumpers

    func testEasyHasBumpersByDefaultAndAstroNeverDoes() {
        let model = GameModel(defaults: defaults)
        XCTAssertTrue(model.easyBumpers)
        model.difficulty = .easy
        model.play()
        XCTAssertTrue(model.scene.bumpers)
        model.difficulty = .astro
        model.play()
        XCTAssertFalse(model.scene.bumpers, "Easy's switch doesn't reach Astro")
    }

    func testTheLessonHasItsOwnBumperSwitchThatAppliesMidRun() {
        let model = GameModel(defaults: defaults)
        model.easyBumpers = false
        model.startLesson()
        XCTAssertTrue(model.scene.bumpers, "on by default in the lesson")
        model.lessonBumpers = false
        XCTAssertFalse(model.scene.bumpers, "switching mid-lesson applies straight away")
    }

    func testBumperSwitchesAreRemembered() {
        let model = GameModel(defaults: defaults)
        model.easyBumpers = false
        model.lessonBumpers = false
        let reloaded = GameModel(defaults: defaults)
        XCTAssertFalse(reloaded.easyBumpers)
        XCTAssertFalse(reloaded.lessonBumpers)
    }

    func testTheMenuDemoNeverHasBumpers() {
        let model = GameModel(defaults: defaults)
        model.difficulty = .easy
        model.play()
        model.goToMenu()
        XCTAssertFalse(model.scene.bumpers)
    }
}
