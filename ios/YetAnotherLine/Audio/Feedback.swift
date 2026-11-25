import UIKit

/// Sound and haptics for game moments, each switchable from Settings. Apple TV has no haptics.
final class Feedback {
    var soundEnabled = true
    var hapticsEnabled = true

    private enum Haptic {
        case light(CGFloat), soft(CGFloat), rigid(CGFloat), heavy
        case warning, error, success
    }

    private let sound = SoundEngine()
    #if os(iOS)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    #endif

    func prepare() {
        #if os(iOS)
        guard hapticsEnabled else { return }
        light.prepare()
        soft.prepare()
        #endif
    }

    func tap() {
        play(.tap)
        haptic(.light(0.5))
    }

    func hooked(combo: Int) {
        if combo > 1 {
            play(.combo(combo))
            haptic(.rigid(min(0.5 + 0.08 * CGFloat(combo), 1)))
        } else {
            play(.hook)
            haptic(.light(0.9))
        }
    }

    func launched() {
        play(.launch)
        haptic(.soft(0.7))
    }

    func bumped() {
        play(.bump)
        haptic(.light(0.8))
    }

    /// A wall hit that Easy still forgives if you latch on quickly.
    func wallHit() {
        play(.warning)
        haptic(.warning)
    }

    func died() {
        play(.death)
        haptic(.heavy, .error)
    }

    func newBest() {
        play(.newBest)
        haptic(.success)
    }

    private func play(_ effect: SoundEngine.Sound) {
        if soundEnabled { sound.play(effect) }
    }

    private func haptic(_ haptics: Haptic...) {
        #if os(iOS)
        guard hapticsEnabled else { return }
        for haptic in haptics {
            switch haptic {
            case let .light(intensity): light.impactOccurred(intensity: intensity)
            case let .soft(intensity): soft.impactOccurred(intensity: intensity)
            case let .rigid(intensity): rigid.impactOccurred(intensity: intensity)
            case .heavy: heavy.impactOccurred()
            case .warning: notification.notificationOccurred(.warning)
            case .error: notification.notificationOccurred(.error)
            case .success: notification.notificationOccurred(.success)
            }
        }
        #endif
    }
}
