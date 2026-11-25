import UIKit

/// Feeds the Siri Remote to the game. During a run a thumb resting on the touch surface latches (no
/// click needed), a click latches too, and Play/Pause or Back pauses. Outside a run everything goes on
/// to the menus as usual. `RemoteRouter` makes the decisions; this applies them.
final class RemoteWindow: UIWindow {
    weak var model: GameModel?
    private var router = RemoteRouter()

    override func sendEvent(_ event: UIEvent) {
        if let model, claim(event, for: model) { return }
        super.sendEvent(event)
    }

    /// Returns true when the game used the event, so the menus (and the system's Back-to-Home) never see it.
    private func claim(_ event: UIEvent, for model: GameModel) -> Bool {
        var claimed = false
        func apply(_ id: AnyHashable, began: Bool, ended: Bool, input: RemoteRouter.Input) {
            let effect: RemoteRouter.Effect
            if began {
                effect = router.began(id, input, isPlaying: model.phase == .playing, touchLatches: model.touchToLatch)
            } else if ended {
                effect = router.ended(id)
            } else {
                effect = router.claims(id) ? .ignore : .passThrough
            }
            switch effect {
            case .passThrough: return
            case .holdBegan: model.scene.holdBegan(id)
            case .holdEnded: model.scene.holdEnded(id)
            case .pause: model.pause()
            case .ignore: break
            }
            claimed = true
        }

        if let presses = (event as? UIPressesEvent)?.allPresses {
            for press in presses {
                guard let input = RemoteWindow.input(for: press.type) else { continue }
                apply(ObjectIdentifier(press), began: press.phase == .began,
                      ended: press.phase == .ended || press.phase == .cancelled, input: input)
            }
        } else if event.type == .touches, let touches = event.allTouches {
            for touch in touches where touch.type == .indirect {
                apply(ObjectIdentifier(touch), began: touch.phase == .began,
                      ended: touch.phase == .ended || touch.phase == .cancelled, input: .touch)
            }
        }
        return claimed
    }

    private static func input(for press: UIPress.PressType) -> RemoteRouter.Input? {
        switch press {
        case .select, .upArrow, .downArrow, .leftArrow, .rightArrow: .click
        case .playPause, .menu: .pause
        default: nil
        }
    }
}
