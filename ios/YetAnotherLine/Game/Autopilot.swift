import CoreGraphics
import Foundation

extension GameWorld {
    /// A look-ahead pilot that flies the menu's demo run (and `-autopilot` debug runs and tests).
    /// It simulates copies of the world to decide whether it should be holding right now.
    func autopilotWantsHold() -> Bool {
        if isHolding {
            guard isOrbiting else { return false }

            // Bail out if the swing itself is about to clip another planet.
            var orbit = self
            if !orbit.survives(for: 0.12, climbing: -.infinity) { return false }

            // Let go once the straight shot is safe and gains height; get less picky the longer we circle,
            // and eventually just go (an orbit hugging a wall may never offer a clean exit).
            let circling = time - lastHookTime
            if circling > 5 { return false }
            var launched = self
            _ = launched.release()
            let safe = circling > 3
                ? launched.survives(for: 0.6, climbing: 0)
                : launched.survives(for: 1.0, climbing: 110)
            return !safe
        }

        guard nearestHookable() != nil else { return false }
        var coasting = self
        if !coasting.survives(for: 0.4, climbing: -.infinity) { return true }
        return velocity.dy < 60
    }

    private mutating func survives(for duration: TimeInterval, climbing minimumClimb: CGFloat) -> Bool {
        let startY = player.y
        var elapsed: TimeInterval = 0
        while elapsed < duration {
            _ = step(Tuning.fixedStep)
            if isDead { return false }
            elapsed += Tuning.fixedStep
        }
        return player.y - startY >= minimumClimb
    }
}
