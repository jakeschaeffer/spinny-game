import SpriteKit
import UIKit

/// Renders a `GameWorld` and feeds it touches. The scene matches the view's size in points; the world
/// layer and the screen-fixed layer are scaled so the 400-unit-wide playfield spans the screen exactly.
final class GameScene: SKScene {
    enum Mode {
        /// Menu backdrop: the autopilot flies a silent demo run.
        case attract
        case playing
        /// The comet just exploded; the game-over card follows shortly.
        case dying
        case gameOver
    }

    weak var model: GameModel?
    var feedback: Feedback?
    var speedMultiplier: CGFloat = 1
    var showsOrbitGuide = true
    var physics = Physics() {
        didSet { world.physics = physics }
    }

    private(set) var mode: Mode = .attract
    private(set) var world: GameWorld
    private var isGamePaused = false
    private var lastUpdateTime: TimeInterval?
    private var clock: TimeInterval = 0
    private var touchesDown = Set<UITouch>()
    private var shakeRemaining: TimeInterval = 0
    private var shakeStrength: CGFloat = 0
    private var reportedScore = -1
    private var reportedCombo = -1
    private var bestToBeat = 0
    private var celebratedBest = false
    private var highlightedID: Int?
    private var guideTargetID: Int?
    private var demoRestartAt: TimeInterval?
    private var planetSignature = [-1, -1, -1]

    private let cam = SKCameraNode()
    /// Camera child in world units: things pinned to the screen (background, walls, flashes, banners).
    private let screenLayer = SKNode()
    private let backdrop = Backdrop()
    private let walls = WallsNode()
    private let flash = SKSpriteNode(color: .white, size: .zero)
    private let worldLayer = SKNode()
    private let markerLayer = SKNode()
    private let planetLayer = SKNode()
    private let guideRing = SKShapeNode()
    private let tether = TetherNode()
    private let trail = TrailNode()
    private let player = PlayerNode()
    private var planetNodes: [Int: PlanetNode] = [:]
    private var markerNodes: [Int: SKNode] = [:]
    private var bestLine: SKNode?
    /// Points per world unit.
    private var unit: CGFloat = 1
    /// Height of the view in world units.
    private var visibleHeight: CGFloat { size.height / unit }

    #if DEBUG
    private let debugAutopilot = ProcessInfo.processInfo.arguments.contains("-autopilot")
    #else
    private let debugAutopilot = false
    #endif

    override init(size: CGSize) {
        world = GameWorld(viewHeight: size.height * GameWorld.Tuning.width / max(size.width, 1),
                          seed: .random(in: 0...UInt64.max))
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = Theme.spaceBottom
        Textures.shared.prewarm()
        buildNodeTree()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildNodeTree() {
        addChild(cam)
        camera = cam
        cam.addChild(screenLayer)
        backdrop.zPosition = -100
        walls.zPosition = 50
        flash.zPosition = 90
        flash.alpha = 0
        flash.blendMode = .add
        for node in [backdrop, walls, flash] { screenLayer.addChild(node) }

        addChild(worldLayer)
        markerLayer.zPosition = 1
        guideRing.zPosition = 4
        planetLayer.zPosition = 10
        trail.zPosition = 15
        tether.zPosition = 18
        player.zPosition = 20
        for node in [markerLayer, guideRing, planetLayer, trail, tether, player] { worldLayer.addChild(node) }
        player.tail.targetNode = worldLayer

        guideRing.lineWidth = 1.4
        guideRing.blendMode = .add
        guideRing.isHidden = true
        guideRing.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 24)))

        layoutForSize()
    }

    private func layoutForSize() {
        guard size.width > 0, size.height > 0 else { return }
        unit = size.width / GameWorld.Tuning.width
        worldLayer.setScale(unit)
        screenLayer.setScale(unit)
        let visible = CGSize(width: GameWorld.Tuning.width, height: visibleHeight)
        backdrop.build(for: visible)
        walls.layout(height: visible.height)
        flash.size = CGSize(width: visible.width + 60, height: visible.height + 60)
        world.viewHeight = visible.height
        updateCamera(0)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard cam.parent != nil, oldSize != size else { return }
        layoutForSize()
    }

    // MARK: Runs

    func showAttract() {
        mode = .attract
        beginRun()
    }

    func startGame() {
        mode = .playing
        beginRun()
        feedback?.prepare()
    }

    func setGamePaused(_ paused: Bool) {
        isGamePaused = paused
        isPaused = paused
        touchesDown.removeAll()
        lastUpdateTime = nil
    }

    private func beginRun() {
        isGamePaused = false
        isPaused = false
        removeAction(forKey: "gameOver")
        world = GameWorld(viewHeight: visibleHeight, seed: .random(in: 0...UInt64.max), physics: physics)
        touchesDown.removeAll()
        clock = 0
        reportedScore = -1
        reportedCombo = -1
        celebratedBest = false
        highlightedID = nil
        guideTargetID = nil
        demoRestartAt = nil
        shakeRemaining = 0

        planetNodes.values.forEach { $0.removeFromParent() }
        planetNodes.removeAll()
        markerNodes.values.forEach { $0.removeFromParent() }
        markerNodes.removeAll()
        bestLine?.removeFromParent()
        bestLine = nil
        bestToBeat = model?.best ?? 0
        if mode == .playing, bestToBeat > 0 {
            let line = makeLine(y: CGFloat(bestToBeat) * GameWorld.Tuning.unitsPerPoint, label: "BEST \(bestToBeat)",
                                color: Theme.gold, alpha: 0.55, alignRight: true)
            markerLayer.addChild(line)
            bestLine = line
        }

        guideRing.isHidden = true
        tether.hide()
        trail.reset()
        player.reset(at: world.player)
        syncPlanets(force: true)
        updateCamera(0)
    }

    // MARK: Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard mode == .playing, !isGamePaused else { return }
        let wasIdle = touchesDown.isEmpty
        touchesDown.formUnion(touches)
        if wasIdle { pressDown() }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        liftTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        liftTouches(touches)
    }

    private func liftTouches(_ touches: Set<UITouch>) {
        guard !touchesDown.isEmpty else { return }
        touchesDown.subtract(touches)
        if touchesDown.isEmpty, mode == .playing { liftUp() }
    }

    private func pressDown() {
        handle(world.press())
        player.setHolding(true)
    }

    private func liftUp() {
        handle(world.release())
        player.setHolding(false)
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = min(currentTime - (lastUpdateTime ?? currentTime), 1.0 / 20.0)
        lastUpdateTime = currentTime
        if isGamePaused {
            isPaused = true
            return
        }

        switch mode {
        case .attract:
            if let restartAt = demoRestartAt {
                clock += dt
                if clock >= restartAt { beginRun() }
            } else {
                advance(by: dt, autopilot: true)
            }
        case .playing:
            advance(by: dt * speedMultiplier, autopilot: debugAutopilot)
        case .dying, .gameOver:
            clock += dt
        }

        updateCamera(dt)
        backdrop.update(cameraBottom: world.cameraBottom)
        renderWorld()
    }

    private func advance(by dt: TimeInterval, autopilot: Bool) {
        guard dt > 0, !world.isDead else { return }
        if autopilot {
            let wantsHold = world.autopilotWantsHold()
            if wantsHold != world.isHolding { wantsHold ? pressDown() : liftUp() }
        }
        clock += dt
        // Equal sub-steps (rather than a fixed step plus remainder) keep motion smooth at any refresh rate.
        let steps = max(1, Int((dt / GameWorld.Tuning.fixedStep).rounded(.up)))
        let h = dt / Double(steps)
        for _ in 0..<steps {
            handle(world.step(h))
            if world.isDead { break }
        }
        if !world.isDead { trail.add(world.player, at: clock) }
    }

    private func handle(_ events: [WorldEvent]) {
        let live = mode == .playing
        for event in events {
            switch event {
            case let .hooked(planetID, combo):
                if live { feedback?.hooked(combo: combo) }
                if let node = planetNodes[planetID] {
                    node.pulse()
                    let palette = Theme.planetPalettes[node.planet.palette]
                    tether.showTrack(around: node.planet.position, radius: world.hookDistance, color: palette.light)
                    if live, combo > 1 { popup("×\(combo)", at: world.player) }
                }
            case .launched:
                if live { feedback?.launched() }
                tether.hide()
            case .died:
                explode()
            }
        }
    }

    private func renderWorld() {
        syncPlanets(force: false)
        player.position = world.player
        trail.redraw(now: clock)
        if world.isOrbiting, !world.isDead, let planet = world.hookedPlanet {
            tether.update(planet: planet, player: world.player)
        } else {
            tether.hide()
        }
        updateGuide()
        updateWalls()
        updateMarkers()
        if mode == .playing { reportProgress() }
    }

    private func updateCamera(_ dt: TimeInterval) {
        var offset = CGPoint.zero
        if shakeRemaining > 0 {
            shakeRemaining = max(0, shakeRemaining - dt)
            let strength = shakeStrength * CGFloat(shakeRemaining / 0.45)
            offset = CGPoint(x: .random(in: -strength...strength), y: .random(in: -strength...strength))
        }
        cam.position = CGPoint(x: (GameWorld.Tuning.width / 2 + offset.x) * unit,
                               y: (world.cameraCenterY + offset.y) * unit)
    }

    private func syncPlanets(force: Bool) {
        let planets = world.planets
        let signature = [planets.count, planets.first?.id ?? -1, planets.last?.id ?? -1]
        guard force || signature != planetSignature else { return }
        planetSignature = signature

        let live = Set(planets.map(\.id))
        for (id, node) in planetNodes where !live.contains(id) {
            node.removeFromParent()
            planetNodes[id] = nil
        }
        for planet in planets where planetNodes[planet.id] == nil {
            let node = PlanetNode(planet: planet)
            planetLayer.addChild(node)
            planetNodes[planet.id] = node
        }
    }

    private func updateGuide() {
        let alive = !world.isDead && mode != .gameOver && mode != .dying
        let nearest = alive && !world.isOrbiting ? world.nearestHookable() : nil
        let highlight = world.isOrbiting ? world.hookedPlanet : nearest
        if highlight?.id != highlightedID {
            if let old = highlightedID { planetNodes[old]?.setHighlighted(false) }
            if let new = highlight { planetNodes[new.id]?.setHighlighted(true) }
            highlightedID = highlight?.id
        }

        guard showsOrbitGuide, let target = nearest else {
            guideRing.isHidden = true
            guideTargetID = nil
            return
        }
        guard guideTargetID != target.id else { return }
        guideTargetID = target.id
        let r = target.hookRadius
        guideRing.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
            .copy(dashingWithPhase: 0, lengths: [7, 9])
        guideRing.strokeColor = Theme.planetPalettes[target.palette].light.withAlphaComponent(0.4)
        guideRing.position = target.position
        guideRing.isHidden = false
        guideRing.alpha = 0
        guideRing.run(.fadeIn(withDuration: 0.15))
    }

    private func updateWalls() {
        guard !world.isOrbiting, !world.isDead, mode == .playing || mode == .attract else {
            walls.setDanger(left: 0, right: 0)
            return
        }
        let x = world.player.x
        let inset = GameWorld.Tuning.wallInset
        let reach: CGFloat = 80
        walls.setDanger(left: min(max(1 - (x - inset) / reach, 0), 1),
                        right: min(max(1 - (GameWorld.Tuning.width - inset - x) / reach, 0), 1))
    }

    private func updateMarkers() {
        let spacing = 100 * GameWorld.Tuning.unitsPerPoint
        let low = Int(((world.cameraBottom - 40) / spacing).rounded(.down))
        let high = Int(((world.cameraBottom + visibleHeight + 40) / spacing).rounded(.up))
        for (index, node) in markerNodes where index < low || index > high {
            node.removeFromParent()
            markerNodes[index] = nil
        }
        guard high >= 1 else { return }
        for index in max(1, low)...high where markerNodes[index] == nil {
            let node = makeLine(y: CGFloat(index) * spacing, label: "\(index * 100)", color: .white, alpha: 0.1, alignRight: false)
            markerLayer.addChild(node)
            markerNodes[index] = node
        }
    }

    private func makeLine(y: CGFloat, label text: String, color: UIColor, alpha: CGFloat, alignRight: Bool) -> SKNode {
        let node = SKNode()
        node.position = CGPoint(x: 0, y: y)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 22, y: 0))
        path.addLine(to: CGPoint(x: GameWorld.Tuning.width - 22, y: 0))
        let line = SKShapeNode(path: path.copy(dashingWithPhase: 0, lengths: [6, 6]))
        line.strokeColor = color.withAlphaComponent(alpha)
        line.lineWidth = 1
        node.addChild(line)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.fontSize = 10
        label.fontColor = color.withAlphaComponent(min(1, alpha * 3))
        label.horizontalAlignmentMode = alignRight ? .right : .left
        label.verticalAlignmentMode = .bottom
        label.position = CGPoint(x: alignRight ? GameWorld.Tuning.width - 22 : 22, y: 4)
        node.addChild(label)
        return node
    }

    private func reportProgress() {
        let score = world.score
        if score != reportedScore {
            reportedScore = score
            model?.scoreChanged(score)
            if !celebratedBest, bestToBeat > 0, score > bestToBeat {
                celebratedBest = true
                feedback?.newBest()
                model?.reachedNewBest()
                banner("NEW BEST")
            }
        }
        let combo = world.liveCombo
        if combo != reportedCombo {
            reportedCombo = combo
            model?.comboChanged(combo)
        }
    }

    // MARK: Effects

    private func explode() {
        let point = world.player
        player.explode()
        tether.hide()
        guideRing.isHidden = true

        let burst = Effects.explosion()
        burst.position = point
        burst.targetNode = worldLayer
        worldLayer.addChild(burst)
        burst.run(.sequence([.wait(forDuration: 2.5), .removeFromParent()]))
        worldLayer.addChild(Effects.shockwave(at: point))

        switch mode {
        case .playing:
            mode = .dying
            feedback?.died()
            if !UIAccessibility.isReduceMotionEnabled {
                shakeRemaining = 0.45
                shakeStrength = 9
            }
            flash.removeAllActions()
            flash.alpha = 0.3
            flash.run(.fadeOut(withDuration: 0.3))
            let summary = (score: world.score, bestCombo: world.bestCombo, duration: world.time)
            run(.sequence([
                .wait(forDuration: 0.9),
                .run { [weak self] in
                    self?.mode = .gameOver
                    self?.model?.runEnded(score: summary.score, bestCombo: summary.bestCombo, duration: summary.duration)
                },
            ]), withKey: "gameOver")
        case .attract:
            demoRestartAt = clock + 1.4
        case .dying, .gameOver:
            break
        }
    }

    private func popup(_ text: String, at point: CGPoint) {
        let label = SKLabelNode(fontNamed: "AvenirNext-HeavyItalic")
        label.text = text
        label.fontSize = 22
        label.fontColor = Theme.gold
        label.position = CGPoint(x: point.x, y: point.y + 22)
        label.zPosition = 30
        label.setScale(0.6)
        worldLayer.addChild(label)
        label.run(.sequence([
            .group([
                .scale(to: 1.1, duration: 0.18),
                .moveBy(x: 0, y: 34, duration: 0.7),
                .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.35)]),
            ]),
            .removeFromParent(),
        ]))
    }

    private func banner(_ text: String) {
        let label = SKLabelNode(fontNamed: "AvenirNext-HeavyItalic")
        label.text = text
        label.fontSize = 30
        label.fontColor = Theme.gold
        label.position = CGPoint(x: 0, y: visibleHeight * 0.16)
        label.zPosition = 80
        label.alpha = 0
        label.setScale(0.7)
        screenLayer.addChild(label)
        label.run(.sequence([
            .group([.fadeIn(withDuration: 0.2), .scale(to: 1, duration: 0.25)]),
            .wait(forDuration: 1.1),
            .group([.fadeOut(withDuration: 0.4), .moveBy(x: 0, y: 20, duration: 0.4)]),
            .removeFromParent(),
        ]))
    }
}
