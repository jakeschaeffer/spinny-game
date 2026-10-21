import Foundation

/// The learning mode's coaching: which tip is showing, and when the player has passed.
struct Lesson: Equatable {
    enum Step: Int, Comparable {
        /// Hold to latch onto a planet.
        case latch
        /// Keep holding to swing around it.
        case swing
        /// Let go to launch.
        case launch
        /// Latch onto the next planet before falling.
        case chain
        /// Walls end a run, but swinging through them while latched is safe.
        case walls
        /// Climb to the goal.
        case climb

        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    enum Outcome: Equatable {
        case crashed(DeathCause)
        case passed
    }

    static let goal = 100
    /// Half speed, with fewer and bigger planets than either mode.
    static let rules = Rules(startSpacing: 2.2, fullSpacing: 2.2, speed: 0.5, radiusRange: 20...32)

    private(set) var step: Step = .latch

    /// How long a timed tip stays up before the next one, in real seconds.
    var stepDuration: Duration? {
        switch step {
        case .swing: .seconds(1.4)
        case .walls: .seconds(5)
        default: nil
        }
    }

    mutating func hooked() {
        switch step {
        case .latch: step = .swing
        case .chain: step = .walls
        default: break
        }
    }

    /// Letting go during the swing tip skips straight past the launch tip: they've already done it.
    mutating func launched() {
        if step == .swing || step == .launch { step = .chain }
    }

    /// A timed tip has been up for its `stepDuration`.
    mutating func stepTimedOut(_ timed: Step) {
        guard step == timed else { return }
        switch step {
        case .swing: step = .launch
        case .walls: step = .climb
        default: break
        }
    }

    /// Passing takes reaching the goal after every tip has been shown.
    func isPassed(score: Int) -> Bool { step == .climb && score >= Lesson.goal }

    /// After a crash the lesson starts over; once the player has launched, it skips the basics.
    mutating func retry() {
        step = step >= .chain ? .chain : .latch
    }
}
