import CoreGraphics
import XCTest
@testable import YetAnotherLine

final class LessonTests: XCTestCase {
    func testTheLessonWalksThroughEveryTipInOrder() {
        var lesson = Lesson()
        XCTAssertEqual(lesson.step, .latch)
        lesson.hooked()
        XCTAssertEqual(lesson.step, .swing)
        lesson.stepTimedOut(.swing)
        XCTAssertEqual(lesson.step, .launch)
        lesson.launched()
        XCTAssertEqual(lesson.step, .chain)
        lesson.hooked()
        XCTAssertEqual(lesson.step, .walls)
        lesson.stepTimedOut(.walls)
        XCTAssertEqual(lesson.step, .climb)
        XCTAssertFalse(lesson.isPassed(score: 99))
        XCTAssertTrue(lesson.isPassed(score: 100))
    }

    func testLettingGoDuringTheSwingTipSkipsTheLaunchTip() {
        var lesson = Lesson()
        lesson.hooked()
        lesson.launched()
        XCTAssertEqual(lesson.step, .chain)
    }

    func testReachingTheGoalEarlyWaitsForTheRemainingTips() {
        var lesson = Lesson()
        lesson.hooked()
        lesson.launched()
        XCTAssertFalse(lesson.isPassed(score: 150), "the wall warning hasn't been shown yet")
    }

    func testAStaleTimerDoesNothing() {
        var lesson = Lesson()
        lesson.hooked()
        lesson.launched()
        lesson.stepTimedOut(.swing)
        XCTAssertEqual(lesson.step, .chain)
    }

    func testRetryingSkipsTheBasicsOnceThePlayerHasLaunched() {
        var early = Lesson()
        early.hooked()
        early.retry()
        XCTAssertEqual(early.step, .latch)

        var late = Lesson()
        late.hooked()
        late.launched()
        late.hooked()
        late.stepTimedOut(.walls)
        late.retry()
        XCTAssertEqual(late.step, .chain)
    }

    func testTheLessonIsSlowerSparserAndBiggerThanEasy() {
        let lesson = Lesson.rules
        let easy = Difficulty.easy.rules
        XCTAssertEqual(lesson.speed, 0.5)
        XCTAssertGreaterThan(lesson.rowSpacing(at: 0), easy.rowSpacing(at: 0))
        XCTAssertGreaterThan(lesson.rowSpacing(at: 800), easy.rowSpacing(at: 800))
        XCTAssertGreaterThan(lesson.radiusRange.lowerBound, easy.radiusRange.lowerBound)
    }

    /// The autopilot should clear the lesson's goal nearly every time: the level itself must never be the obstacle.
    func testTheLessonWorldIsEasyToClear() {
        let step = GameWorld.Tuning.fixedStep
        var cleared = 0
        for seed in UInt64(1)...20 {
            var world = GameWorld(viewHeight: 869, seed: seed, rules: Lesson.rules)
            var ticks = 0
            while !world.isDead, world.score < Lesson.goal, Double(ticks) * step < 30 {
                if ticks.isMultiple(of: 4) {
                    let wantsHold = world.autopilotWantsHold()
                    if wantsHold != world.isHolding { _ = wantsHold ? world.press() : world.release() }
                }
                _ = world.step(step)
                ticks += 1
            }
            if world.score >= Lesson.goal { cleared += 1 }
        }
        XCTAssertGreaterThanOrEqual(cleared, 19)
    }
}
