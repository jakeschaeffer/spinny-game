import CoreGraphics
import Foundation

/// What sets one mode apart from another. The defaults are Astro, the original game.
struct Rules: Equatable {
    /// Gap between planet rows relative to `GameWorld.Tuning.rowGap`, at the start of a run and from
    /// `GameWorld.Tuning.fullDensityHeight` up. Bigger means fewer planets.
    var startSpacing: CGFloat = 1.75
    var fullSpacing: CGFloat = 1
    /// How fast the game runs, on top of the game speed setting.
    var speed: Double = 1
    /// Real seconds you get to latch onto a planet after flying into a wall, before it counts as a
    /// crash. 0 makes walls fatal straight away.
    var wallGrace: TimeInterval = 0

    /// Row spacing at height `y`: sparse at the start, easing linearly to full density.
    func rowSpacing(at y: CGFloat) -> CGFloat {
        let progress = min(max(y / GameWorld.Tuning.fullDensityHeight, 0), 1)
        return startSpacing + (fullSpacing - startSpacing) * progress
    }
}

/// The modes picked in Settings. Each keeps its own best score.
enum Difficulty: String, CaseIterable, Identifiable {
    case easy, astro

    var id: Self { self }

    var title: String {
        switch self {
        case .easy: "Easy"
        case .astro: "Astro (Hard)"
        }
    }

    /// Short label for badges.
    var badge: String {
        switch self {
        case .easy: "EASY"
        case .astro: "ASTRO"
        }
    }

    var rules: Rules {
        switch self {
        case .easy: Rules(startSpacing: 2.1, fullSpacing: 1.3, speed: 0.85, wallGrace: 0.3)
        case .astro: Rules()
        }
    }
}
