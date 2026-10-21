import GameKit
import Observation
import UIKit

/// Game Center sign-in and the per-mode leaderboards. The leaderboards themselves are set up in App
/// Store Connect (see RELEASING.md); until they exist, submissions fail quietly.
@MainActor
@Observable
final class GameCenter {
    private(set) var isAuthenticated = false

    /// Scores waiting for sign-in: a player's local bests go up the moment they sign in.
    @ObservationIgnored var pendingBests: () -> [Difficulty: Int] = { [:] }

    static func leaderboardID(for difficulty: Difficulty) -> String {
        "com.jakeschaeffer.onemoreline.score.\(difficulty.rawValue)"
    }

    /// Signs in at launch. Game Center shows its own welcome banner, or hands over a sign-in sheet.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let viewController { Self.present(viewController) }
                let wasAuthenticated = self.isAuthenticated
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if self.isAuthenticated, !wasAuthenticated {
                    for (difficulty, best) in self.pendingBests() { self.submit(best: best, for: difficulty) }
                }
            }
        }
    }

    /// Posts a mode's best score. Game Center keeps the highest, so posting the same best again is harmless.
    func submit(best: Int, for difficulty: Difficulty) {
        guard isAuthenticated, best > 0 else { return }
        GKLeaderboard.submitScore(best, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [Self.leaderboardID(for: difficulty)]) { _ in }
    }

    func showLeaderboard(for difficulty: Difficulty) {
        if #available(iOS 18.0, *) {
            GKAccessPoint.shared.trigger(leaderboardID: Self.leaderboardID(for: difficulty),
                                         playerScope: .global, timeScope: .allTime) {}
        } else {
            GKAccessPoint.shared.trigger(state: .leaderboards) {}
        }
    }

    private static func present(_ viewController: UIViewController) {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        top?.present(viewController, animated: true)
    }
}
