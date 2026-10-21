import Foundation
import Observation
import SpriteKit

/// App state shared by the SwiftUI overlays and the SpriteKit scene.
@MainActor
@Observable
final class GameModel {
    enum Phase: Equatable {
        case menu, playing, paused, gameOver
        /// The lesson ended, by a crash or by passing: see `lessonOutcome`.
        case lessonOver
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
    /// The learning mode in progress, or nil in a normal run.
    private(set) var lesson: Lesson?
    private(set) var lessonOutcome: Lesson.Outcome?
    var showSettings = false
    /// Set when the leaderboard button is tapped while signed out of Game Center.
    var showGameCenterSignIn = false

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
    let gameCenter = GameCenter()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var tutorialTask: Task<Void, Never>?
    @ObservationIgnored private var lessonTask: Task<Void, Never>?

    private enum Keys {
        static let difficulty = "oneMoreLine.difficulty"
        static let sound = "oneMoreLine.sound"
        static let haptics = "oneMoreLine.haptics"
        static let guide = "oneMoreLine.orbitGuide"
        static let physics = "oneMoreLine.physics"
        static let speed = "oneMoreLine.speed"
        static let lessonSeen = "oneMoreLine.lessonSeen"
        static let lessonPassed = "oneMoreLine.lessonPassed"

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
        gameCenter.pendingBests = { [weak self] in self?.bests ?? [:] }
    }

    /// The mode the screen is about: the one picked on the menu, otherwise the current run's.
    var shownDifficulty: Difficulty { phase == .menu ? difficulty : runDifficulty }
    var best: Int { bests[shownDifficulty] ?? 0 }
    var bestCombo: Int { bestCombos[shownDifficulty] ?? 0 }

    // MARK: Navigation

    func play() {
        // A brand-new player's first launch goes to the lesson.
        if !defaults.bool(forKey: Keys.lessonSeen), bests.values.allSatisfy({ $0 == 0 }) {
            startLesson()
            return
        }
        feedback.tap()
        resetRun()
        lesson = nil
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

    /// Plays the current kind of run again: the lesson from the pause card's restart, otherwise a new run.
    func restart() {
        if lesson != nil { retryLesson() } else { play() }
    }

    func startLesson() {
        defaults.set(true, forKey: Keys.lessonSeen)
        lesson = Lesson()
        beginLessonRun()
    }

    func retryLesson() {
        lesson?.retry()
        beginLessonRun()
    }

    private func beginLessonRun() {
        feedback.tap()
        resetRun()
        lessonOutcome = nil
        tutorialTask?.cancel()
        showTutorial = false
        phase = .playing
        scene.startLesson(rules: Lesson.rules)
        scheduleLessonStep()
    }

    private func resetRun() {
        score = 0
        combo = 0
        passedBest = false
        lastRun = nil
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
        lessonTask?.cancel()
        showTutorial = false
        lesson = nil
        lessonOutcome = nil
        phase = .menu
        scene.showAttract()
    }

    func showLeaderboard() {
        feedback.tap()
        if gameCenter.isAuthenticated {
            gameCenter.showLeaderboard(for: shownDifficulty)
        } else {
            showGameCenterSignIn = true
        }
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

    func scoreChanged(_ value: Int) {
        score = value
        checkLessonPassed()
    }

    func playerHooked() {
        advanceLesson { $0.hooked() }
    }

    func playerLaunched() {
        advanceLesson { $0.launched() }
    }

    func lessonCrashed(_ cause: DeathCause) {
        lessonTask?.cancel()
        combo = 0
        lessonOutcome = .crashed(cause)
        phase = .lessonOver
    }

    func comboChanged(_ value: Int) { combo = value }

    func reachedNewBest() { passedBest = true }

    func runEnded(score: Int, bestCombo: Int, duration: TimeInterval) {
        // Anyone who has finished a run knows the basics, so LAUNCH won't send them to the lesson.
        defaults.set(true, forKey: Keys.lessonSeen)
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
        gameCenter.submit(best: bests[runDifficulty] ?? 0, for: runDifficulty)
        combo = 0
        tutorialTask?.cancel()
        showTutorial = false
        phase = .gameOver
    }

    // MARK: Lesson

    /// Restarts the tip timer only when the step changes, so latching again and again can't hold a timed
    /// tip up forever.
    private func advanceLesson(_ change: (inout Lesson) -> Void) {
        guard var lesson else { return }
        let before = lesson.step
        change(&lesson)
        self.lesson = lesson
        if lesson.step != before { scheduleLessonStep() }
    }

    /// Moves a timed tip along once it's had time to be read.
    private func scheduleLessonStep() {
        lessonTask?.cancel()
        guard let lesson, let duration = lesson.stepDuration else { return }
        let step = lesson.step
        lessonTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self, self.phase == .playing || self.phase == .paused else { return }
            self.lesson?.stepTimedOut(step)
            self.scheduleLessonStep()
            self.checkLessonPassed()
        }
    }

    private func checkLessonPassed() {
        guard phase == .playing, let lesson, lesson.isPassed(score: score) else { return }
        lessonTask?.cancel()
        defaults.set(true, forKey: Keys.lessonPassed)
        combo = 0
        lessonOutcome = .passed
        phase = .lessonOver
        feedback.newBest()
        scene.finishLesson()
    }
}
