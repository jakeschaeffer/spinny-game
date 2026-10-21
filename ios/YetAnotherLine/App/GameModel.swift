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
        let isNewBestCombo: Bool
    }

    private(set) var phase: Phase = .menu
    private(set) var score = 0
    private(set) var combo = 0
    /// Each mode's best score and best combo.
    private(set) var bests: [Difficulty: Int]
    private(set) var bestCombos: [Difficulty: Int]
    /// The mode of the run in progress or just finished. Changing `difficulty` applies from the next run.
    private(set) var runDifficulty: Difficulty
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
    var difficulty: Difficulty {
        didSet { defaults.set(difficulty.rawValue, forKey: Keys.difficulty) }
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
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var tutorialTask: Task<Void, Never>?

    private enum Keys {
        static let difficulty = "oneMoreLine.difficulty"
        static let sound = "oneMoreLine.sound"
        static let haptics = "oneMoreLine.haptics"
        static let guide = "oneMoreLine.orbitGuide"
        static let physics = "oneMoreLine.physics"
        static let speed = "oneMoreLine.speed"

        static func best(_ difficulty: Difficulty) -> String {
            // Astro keeps the original key, so existing players' best carries over as their Astro best.
            difficulty == .astro ? "oneMoreLine.best" : "oneMoreLine.best.\(difficulty.rawValue)"
        }

        static func bestCombo(_ difficulty: Difficulty) -> String { "oneMoreLine.bestCombo.\(difficulty.rawValue)" }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Keys.sound: true, Keys.haptics: true, Keys.guide: true, Keys.speed: 1.0])
        let difficulty = defaults.string(forKey: Keys.difficulty).flatMap(Difficulty.init(rawValue:)) ?? .astro
        self.difficulty = difficulty
        runDifficulty = difficulty
        bests = Dictionary(uniqueKeysWithValues: Difficulty.allCases.map { ($0, defaults.integer(forKey: Keys.best($0))) })
        bestCombos = Dictionary(uniqueKeysWithValues: Difficulty.allCases.map {
            ($0, defaults.integer(forKey: Keys.bestCombo($0)))
        })
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

    /// The mode the screen is about: the one picked on the menu, otherwise the current run's.
    var shownDifficulty: Difficulty { phase == .menu ? difficulty : runDifficulty }
    var best: Int { bests[shownDifficulty] ?? 0 }
    var bestCombo: Int { bestCombos[shownDifficulty] ?? 0 }

    // MARK: Navigation

    func play() {
        feedback.tap()
        score = 0
        combo = 0
        passedBest = false
        lastRun = nil
        runDifficulty = difficulty
        phase = .playing
        scene.startGame(rules: runDifficulty.rules)

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

    func resetBests() {
        for difficulty in Difficulty.allCases {
            bests[difficulty] = 0
            bestCombos[difficulty] = 0
            defaults.set(0, forKey: Keys.best(difficulty))
            defaults.set(0, forKey: Keys.bestCombo(difficulty))
        }
    }

    // MARK: Scene callbacks

    func scoreChanged(_ value: Int) { score = value }

    func comboChanged(_ value: Int) { combo = value }

    func reachedNewBest() { passedBest = true }

    func runEnded(score: Int, bestCombo: Int, duration: TimeInterval) {
        let isNewBest = score > bests[runDifficulty] ?? 0
        if isNewBest {
            bests[runDifficulty] = score
            defaults.set(score, forKey: Keys.best(runDifficulty))
        }
        // A single latch isn't a combo, so ×1 never counts as a record.
        let isNewBestCombo = bestCombo > 1 && bestCombo > bestCombos[runDifficulty] ?? 0
        if isNewBestCombo {
            bestCombos[runDifficulty] = bestCombo
            defaults.set(bestCombo, forKey: Keys.bestCombo(runDifficulty))
        }
        lastRun = RunSummary(score: score, bestCombo: bestCombo, duration: duration, isNewBest: isNewBest,
                             isNewBestCombo: isNewBestCombo)
        combo = 0
        tutorialTask?.cancel()
        showTutorial = false
        phase = .gameOver
    }
}
