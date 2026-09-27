import UIKit

/// Sound and haptics for game moments, each switchable from Settings.
final class Feedback {
    var soundEnabled = true
    var hapticsEnabled = true

    private let sound = SoundEngine()
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    func prepare() {
        guard hapticsEnabled else { return }
        light.prepare()
        soft.prepare()
    }

    func tap() {
        play(.tap)
        haptic { light.impactOccurred(intensity: 0.5) }
    }

    func hooked(combo: Int) {
        if combo > 1 {
            play(.combo(combo))
            haptic { rigid.impactOccurred(intensity: min(0.5 + 0.08 * CGFloat(combo), 1)) }
        } else {
            play(.hook)
            haptic { light.impactOccurred(intensity: 0.9) }
        }
    }

    func launched() {
        play(.launch)
        haptic { soft.impactOccurred(intensity: 0.7) }
    }

    func died() {
        play(.death)
        haptic {
            heavy.impactOccurred()
            notification.notificationOccurred(.error)
        }
    }

    func newBest() {
        play(.newBest)
        haptic { notification.notificationOccurred(.success) }
    }

    private func play(_ effect: SoundEngine.Sound) {
        if soundEnabled { sound.play(effect) }
    }

    private func haptic(_ fire: () -> Void) {
        if hapticsEnabled { fire() }
    }
}
