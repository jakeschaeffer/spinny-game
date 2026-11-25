import CoreGraphics
import XCTest
@testable import YetAnotherLine

final class RemoteRouterTests: XCTestCase {
    func testOutsideARunEverythingPassesThroughToTheMenus() {
        var router = RemoteRouter()
        for input in [RemoteRouter.Input.touch, .click, .pause] {
            XCTAssertEqual(router.began(1, input, isPlaying: false, touchLatches: true), .passThrough)
            XCTAssertEqual(router.ended(1), .passThrough)
        }
    }

    func testRestingAThumbOnTheRemoteLatchesAndLiftingItLaunches() {
        var router = RemoteRouter()
        XCTAssertEqual(router.began(1, .touch, isPlaying: true, touchLatches: true), .holdBegan)
        XCTAssertTrue(router.claims(1), "the touch moving about shouldn't reach the menus")
        XCTAssertEqual(router.ended(1), .holdEnded)
        XCTAssertFalse(router.claims(1))
    }

    func testWithTouchToLatchOffATouchDoesNothingButAClickStillLatches() {
        var router = RemoteRouter()
        XCTAssertEqual(router.began(1, .touch, isPlaying: true, touchLatches: false), .ignore)
        XCTAssertEqual(router.began(2, .click, isPlaying: true, touchLatches: false), .holdBegan)
        XCTAssertEqual(router.ended(2), .holdEnded)
    }

    func testPlayPauseAndBackPauseARun() {
        var router = RemoteRouter()
        XCTAssertEqual(router.began(1, .pause, isPlaying: true, touchLatches: true), .pause)
    }

    /// The click that presses LAUNCH begins on the menu and ends once the run has started.
    func testTheEndOfTheClickThatStartedTheRunStaysWithTheMenu() {
        var router = RemoteRouter()
        XCTAssertEqual(router.began(1, .click, isPlaying: false, touchLatches: true), .passThrough)
        XCTAssertEqual(router.ended(1), .passThrough)
    }

    /// The press that pauses begins in the run and ends on the pause card, where a Back press resumes.
    func testTheEndOfThePressThatPausedNeverReachesThePauseCard() {
        var router = RemoteRouter()
        XCTAssertEqual(router.began(1, .pause, isPlaying: true, touchLatches: true), .pause)
        XCTAssertNotEqual(router.ended(1), .passThrough)
    }

    func testThePlayfieldFillsAPhoneAndIsAColumnOnATV() {
        XCTAssertEqual(GameScene.playfieldWidth(in: CGSize(width: 440, height: 956)), 440)
        XCTAssertEqual(GameScene.playfieldWidth(in: CGSize(width: 1920, height: 1080)), 648)
    }
}
