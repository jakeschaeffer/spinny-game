import XCTest
@testable import YetAnotherLine

@MainActor
final class GameCenterTests: XCTestCase {
    /// These IDs must match the leaderboards set up in App Store Connect (see RELEASING.md).
    func testEachModeHasItsOwnLeaderboard() {
        XCTAssertEqual(GameCenter.leaderboardID(for: .astro), "com.jakeschaeffer.onemoreline.score.astro")
        XCTAssertEqual(GameCenter.leaderboardID(for: .easy), "com.jakeschaeffer.onemoreline.score.easy")
    }

    func testTheLeaderboardButtonAsksToSignInWhenSignedOut() {
        let defaults = UserDefaults(suiteName: "GameCenterTests")!
        defaults.removePersistentDomain(forName: "GameCenterTests")
        let model = GameModel(defaults: defaults)
        XCTAssertFalse(model.gameCenter.isAuthenticated)
        model.showLeaderboard()
        XCTAssertTrue(model.showGameCenterSignIn)
    }
}
