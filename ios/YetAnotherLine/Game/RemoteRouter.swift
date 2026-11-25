import Foundation

/// Decides what each Siri Remote touch and button press does on Apple TV. During a run the game claims
/// them: resting a thumb on the touch surface (or holding a click) latches, and Play/Pause or Back
/// pauses. The rest of the time they pass through to the menus.
///
/// An input belongs to whoever saw it begin, for its whole life. That keeps the end of the click that
/// pressed LAUNCH away from the game, and the end of the press that paused away from the pause card.
struct RemoteRouter {
    enum Input: Equatable {
        /// A finger on the touch surface.
        case touch
        /// The centre button or a direction click, or a game controller's A button.
        case click
        /// Play/Pause or Back.
        case pause
    }

    enum Effect: Equatable {
        /// Not the game's: hand it to the menus.
        case passThrough
        case holdBegan, holdEnded
        case pause
        /// The game's, but it does nothing.
        case ignore
    }

    private var claimed = Set<AnyHashable>()

    func claims(_ id: AnyHashable) -> Bool { claimed.contains(id) }

    mutating func began(_ id: AnyHashable, _ input: Input, isPlaying: Bool, touchLatches: Bool) -> Effect {
        guard isPlaying else { return .passThrough }
        claimed.insert(id)
        switch input {
        case .touch: return touchLatches ? .holdBegan : .ignore
        case .click: return .holdBegan
        case .pause: return .pause
        }
    }

    mutating func ended(_ id: AnyHashable) -> Effect {
        claimed.remove(id) == nil ? .passThrough : .holdEnded
    }
}
