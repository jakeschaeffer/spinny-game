import Foundation
import Observation
import SpriteKit

/// App state shared by the SwiftUI overlays and the SpriteKit scene.
@MainActor
@Observable
final class GameModel {
    enum Phase: Equatable {
        case menu, playing, paused, gameOver
    }

    struct RunSummary: Equatable {
        let score: Int
        let bestCombo: Int
        let duration: TimeInterval
        let isNewBest: Bool
    }

    private(set) var phase: Phase = .menu
    private(set) var score = 0
    private(set) var combo = 0
    private(set) var best: Int
    private(set) var passedBest = false
    private(set) var showTutorial = false
    private(set) var lastRun: RunSummary?
    var showSettings = false

    var soundEnabled: Bool {
        didSet {
            defaults.set(soundEnabled, forKey: Keys.sound)
            feedback.soundEnabled = soundEnabled
        }
    }
    var hapticsEnabled: Bool {
        didSet {
            defaults.set(hapticsEnabled, forKey: Keys.haptics)
            feedback.hapticsEnabled = hapticsEnabled
        }
    }
    var showOrbitGuide: Bool {
        didSet {
            defaults.set(showOrbitGuide, forKey: Keys.guide)
            scene.showsOrbitGuide = showOrbitGuide
        }
    }
    var physics: Physics {
        didSet {
            defaults.set(try? JSONEncoder().encode(physics), forKey: Keys.physics)
            scene.physics = physics
        }
    }
    var gameSpeed: Double {
        didSet {
            defaults.set(gameSpeed, forKey: Keys.speed)
            scene.speedMultiplier = CGFloat(gameSpeed)
        }
    }

    let scene: GameScene
    let feedback = Feedback()
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var tutorialTask: Task<Void, Never>?

    private enum Keys {
        static let best = "oneMoreLine.best"
        static let sound = "oneMoreLine.sound"
        static let haptics = "oneMoreLine.haptics"
        static let guide = "oneMoreLine.orbitGuide"
        static let physics = "oneMoreLine.physics"
        static let speed = "oneMoreLine.speed"
    }

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Keys.sound: true, Keys.haptics: true, Keys.guide: true, Keys.speed: 1.0])
        best = defaults.integer(forKey: Keys.best)
        soundEnabled = defaults.bool(forKey: Keys.sound)
        hapticsEnabled = defaults.bool(forKey: Keys.haptics)
        showOrbitGuide = defaults.bool(forKey: Keys.guide)
        physics = defaults.data(forKey: Keys.physics).flatMap { try? JSONDecoder().decode(Physics.self, from: $0) } ?? Physics()
        gameSpeed = defaults.double(forKey: Keys.speed)
        scene = GameScene(size: CGSize(width: GameWorld.Tuning.width, height: 870))

        feedback.soundEnabled = soundEnabled
        feedback.hapticsEnabled = hapticsEnabled
        scene.model = self
        scene.feedback = feedback
        scene.showsOrbitGuide = showOrbitGuide
        scene.physics = physics
        scene.speedMultiplier = CGFloat(gameSpeed)
        scene.showAttract()
    }

    // MARK: Navigation

    func play() {
        feedback.tap()
        score = 0
        combo = 0
        passedBest = false
        lastRun = nil
        phase = .playing
        scene.startGame()

        showTutorial = true
        tutorialTask?.cancel()
        tutorialTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(GameWorld.Tuning.gracePeriod + 0.2))
            guard !Task.isCancelled else { return }
            self?.showTutorial = false
        }
    }

    func pause() {
        guard phase == .playing else { return }
        phase = .paused
        scene.setGamePaused(true)
    }

    func resume() {
        guard phase == .paused else { return }
        feedback.tap()
        phase = .playing
        scene.setGamePaused(false)
    }

    func goToMenu() {
        feedback.tap()
        tutorialTask?.cancel()
        showTutorial = false
        phase = .menu
        scene.showAttract()
    }

    func resetBest() {
        best = 0
        defaults.set(0, forKey: Keys.best)
    }

    // MARK: Scene callbacks

    func scoreChanged(_ value: Int) { score = value }

    func comboChanged(_ value: Int) { combo = value }

    func reachedNewBest() { passedBest = true }

    func runEnded(score: Int, bestCombo: Int, duration: TimeInterval) {
        let isNewBest = score > best
        if isNewBest {
            best = score
            defaults.set(score, forKey: Keys.best)
        }
        lastRun = RunSummary(score: score, bestCombo: bestCombo, duration: duration, isNewBest: isNewBest)
        combo = 0
        tutorialTask?.cancel()
        showTutorial = false
        phase = .gameOver
    }
}
