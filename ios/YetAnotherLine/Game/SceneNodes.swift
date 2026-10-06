import SpriteKit
import UIKit

// MARK: - Planet

final class PlanetNode: SKNode {
    let planet: Planet
    private let glow: SKSpriteNode
    private var isHighlighted = false
    private var restingGlowAlpha: CGFloat { planet.style == .star ? 0.75 : 0.4 }

    init(planet: Planet) {
        self.planet = planet
        let textures = Textures.shared
        let palette = Theme.planetPalettes[planet.palette]
        let diameter = planet.radius * 2
        let glowScale: CGFloat = planet.style == .star ? 4.2 : 2.6
        glow = SKSpriteNode(texture: textures.softGlow, size: CGSize(width: diameter * glowScale, height: diameter * glowScale))
        super.init()
        position = planet.position

        glow.color = palette.main
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = restingGlowAlpha
        glow.zPosition = -2
        addChild(glow)

        let body = SKSpriteNode(texture: textures.planet(style: planet.style, palette: planet.palette),
                                size: CGSize(width: diameter, height: diameter))
        addChild(body)

        if let tilt = planet.ringTilt {
            let ring = SKNode()
            ring.zRotation = tilt
            let width = diameter * 2.3
            let size = CGSize(width: width, height: width * 0.15625)
            let back = SKSpriteNode(texture: textures.ringBack, size: size)
            back.anchorPoint = CGPoint(x: 0.5, y: 0)
            back.zPosition = -1
            let front = SKSpriteNode(texture: textures.ringFront, size: size)
            front.anchorPoint = CGPoint(x: 0.5, y: 1)
            front.zPosition = 1
            for half in [back, front] {
                half.color = palette.light
                half.colorBlendFactor = 1
                half.alpha = 0.8
                ring.addChild(half)
            }
            addChild(ring)
        }

        if planet.style == .star {
            glow.run(.repeatForever(.sequence([
                .scale(to: 1.12, duration: 1.1),
                .scale(to: 0.96, duration: 1.1),
            ])))
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setHighlighted(_ highlighted: Bool) {
        guard highlighted != isHighlighted else { return }
        isHighlighted = highlighted
        removeAction(forKey: "highlight")
        run(.scale(to: highlighted ? 1.1 : 1, duration: 0.15), withKey: "highlight")
        glow.run(.fadeAlpha(to: highlighted ? min(1, restingGlowAlpha + 0.3) : restingGlowAlpha, duration: 0.15))
    }

    /// A ring of light that ripples off the planet when the player latches on.
    func pulse() {
        let ring = SKShapeNode(circleOfRadius: planet.radius + 2)
        ring.strokeColor = Theme.planetPalettes[planet.palette].light
        ring.lineWidth = 2
        ring.blendMode = .add
        ring.zPosition = 2
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.9, duration: 0.4), .fadeOut(withDuration: 0.4)]),
            .removeFromParent(),
        ]))
    }
}

// MARK: - Player

final class PlayerNode: SKNode {
    let tail = SKEmitterNode()
    private let glow = SKSpriteNode(texture: Textures.shared.softGlow)
    private let core = SKSpriteNode(texture: Textures.shared.dot)

    override init() {
        super.init()
        glow.color = Theme.cyan
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.size = CGSize(width: 46, height: 46)
        glow.alpha = 0.85
        core.size = CGSize(width: 12, height: 12)

        tail.particleTexture = Textures.shared.softGlow
        tail.particleBirthRate = 170
        tail.particleLifetime = 0.7
        tail.particleLifetimeRange = 0.3
        tail.particlePositionRange = CGVector(dx: 4, dy: 4)
        tail.particleSpeed = 10
        tail.particleSpeedRange = 10
        tail.emissionAngleRange = .pi * 2
        tail.particleAlpha = 0.65
        tail.particleAlphaRange = 0.2
        tail.particleAlphaSpeed = -0.95
        tail.particleScale = 0.085
        tail.particleScaleRange = 0.03
        tail.particleScaleSpeed = -0.11
        tail.particleColorBlendFactor = 1
        tail.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [UIColor.white, Theme.cyan, Theme.violet, Theme.magenta.withAlphaComponent(0)],
            times: [0, 0.2, 0.6, 1])
        tail.particleBlendMode = .add
        tail.zPosition = -1

        addChild(tail)
        addChild(glow)
        addChild(core)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reset(at point: CGPoint) {
        position = point
        core.isHidden = false
        glow.isHidden = false
        tail.particleBirthRate = 170
        tail.resetSimulation()
        setHolding(false)
    }

    func setHolding(_ holding: Bool) {
        glow.removeAction(forKey: "hold")
        let side: CGFloat = holding ? 60 : 46
        glow.run(.group([
            .resize(toWidth: side, height: side, duration: 0.12),
            .fadeAlpha(to: holding ? 1 : 0.85, duration: 0.12),
        ]), withKey: "hold")
    }

    func explode() {
        core.isHidden = true
        glow.isHidden = true
        tail.particleBirthRate = 0
    }
}

// MARK: - Trail

/// The "line": a glowing ribbon that tapers and fades toward its tail. SKShapeNode can't fade along a
/// path, so the ribbon is split into segments that each get their own width and alpha.
final class TrailNode: SKNode {
    private var points: [CGPoint] = []
    private var stamps: [TimeInterval] = []
    private var cores: [SKShapeNode] = []
    private var glows: [SKShapeNode] = []
    private let lifetime: TimeInterval = 0.85
    private let segmentCount = 8

    override init() {
        super.init()
        for index in 0..<segmentCount {
            let fraction = CGFloat(index + 1) / CGFloat(segmentCount)
            let color = Theme.trailColor(at: fraction)
            let glow = SKShapeNode()
            glow.strokeColor = color.withAlphaComponent(0.05 + 0.13 * fraction)
            glow.lineWidth = 3 + 9 * fraction
            let core = SKShapeNode()
            core.strokeColor = color.withAlphaComponent(0.25 + 0.75 * fraction)
            core.lineWidth = 0.8 + 2.6 * fraction
            for node in [glow, core] {
                node.lineCap = .round
                node.lineJoin = .round
                node.blendMode = .add
                addChild(node)
            }
            glows.append(glow)
            cores.append(core)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reset() {
        points.removeAll()
        stamps.removeAll()
        for node in cores + glows { node.path = nil }
    }

    func add(_ point: CGPoint, at time: TimeInterval) {
        if let last = points.last, last.distance(to: point) < 0.5 { return }
        points.append(point)
        stamps.append(time)
    }

    func redraw(now: TimeInterval) {
        var expired = 0
        while expired < stamps.count && now - stamps[expired] > lifetime { expired += 1 }
        if expired > 0 {
            points.removeFirst(expired)
            stamps.removeFirst(expired)
        }

        guard points.count >= 2 else {
            for node in cores + glows where node.path != nil { node.path = nil }
            return
        }
        let last = points.count - 1
        for index in 0..<segmentCount {
            let start = index * last / segmentCount
            let end = (index + 1) * last / segmentCount
            guard end > start else {
                cores[index].path = nil
                glows[index].path = nil
                continue
            }
            let path = CGMutablePath()
            path.move(to: points[start])
            for i in (start + 1)...end { path.addLine(to: points[i]) }
            cores[index].path = path
            glows[index].path = path
        }
    }
}

// MARK: - Tether

/// The beam from the planet to the comet while orbiting, plus a faint dashed track of the orbit.
final class TetherNode: SKNode {
    private let glow = SKShapeNode()
    private let core = SKShapeNode()
    private let track = SKShapeNode()

    override init() {
        super.init()
        track.lineWidth = 1
        track.zPosition = -2
        track.blendMode = .add
        glow.strokeColor = Theme.cyan.withAlphaComponent(0.28)
        glow.lineWidth = 7
        core.strokeColor = UIColor(white: 1, alpha: 0.95)
        core.lineWidth = 1.6
        for node in [glow, core] {
            node.lineCap = .round
            node.blendMode = .add
        }
        addChild(track)
        addChild(glow)
        addChild(core)
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showTrack(around center: CGPoint, radius: CGFloat, color: UIColor) {
        track.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
            .copy(dashingWithPhase: 0, lengths: [4, 8])
        track.position = center
        track.strokeColor = color.withAlphaComponent(0.25)
    }

    func update(planet: Planet, player: CGPoint) {
        let dx = player.x - planet.position.x
        let dy = player.y - planet.position.y
        let length = max(hypot(dx, dy), 0.001)
        let start = CGPoint(x: planet.position.x + dx / length * planet.radius,
                            y: planet.position.y + dy / length * planet.radius)
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: player)
        glow.path = path
        core.path = path
        glow.alpha = .random(in: 0.7...1)
        isHidden = false
    }

    func hide() {
        if !isHidden { isHidden = true }
    }
}

// MARK: - Walls

/// Force-field walls on both screen edges. They blush toward red as the comet drifts close.
final class WallsNode: SKNode {
    private let left = SKSpriteNode(texture: Textures.shared.wall)
    private let right = SKSpriteNode(texture: Textures.shared.wall)
    private let leftMotes = SKEmitterNode()
    private let rightMotes = SKEmitterNode()

    override init() {
        super.init()
        for wall in [left, right] {
            wall.color = Theme.cyan
            wall.colorBlendFactor = 1
            wall.blendMode = .add
            wall.alpha = 0.7
            addChild(wall)
        }
        for motes in [leftMotes, rightMotes] {
            motes.particleTexture = Textures.shared.softGlow
            motes.particleBirthRate = 5
            motes.particleLifetime = 4
            motes.particleSpeed = 45
            motes.particleSpeedRange = 25
            motes.emissionAngle = .pi / 2
            motes.particleScale = 0.035
            motes.particleScaleRange = 0.015
            motes.particleAlpha = 0.7
            motes.particleAlphaSpeed = -0.15
            motes.particleColor = Theme.cyan
            motes.particleColorBlendFactor = 1
            motes.particleBlendMode = .add
            motes.zPosition = 1
            addChild(motes)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func layout(height: CGFloat) {
        let x = GameWorld.Tuning.width / 2 - 6
        for (wall, motes, side) in [(left, leftMotes, -1.0), (right, rightMotes, 1.0)] {
            wall.size = CGSize(width: 26, height: height + 80)
            wall.position = CGPoint(x: x * side, y: 0)
            motes.position = CGPoint(x: x * side, y: 0)
            motes.particlePositionRange = CGVector(dx: 2, dy: height)
            motes.resetSimulation()
            motes.advanceSimulationTime(4)
        }
    }

    func setDanger(left leftDanger: CGFloat, right rightDanger: CGFloat) {
        left.color = Theme.cyan.mixed(with: Theme.danger, leftDanger)
        left.alpha = 0.7 + 0.3 * leftDanger
        right.color = Theme.cyan.mixed(with: Theme.danger, rightDanger)
        right.alpha = 0.7 + 0.3 * rightDanger
    }
}

// MARK: - Backdrop

/// Deep-space background: a gradient plus parallax layers of nebulae and stars. Each layer is two
/// identical tiles stacked vertically and scrolled a fraction of the camera's travel.
final class Backdrop: SKNode {
    private struct Layer {
        let tiles: [SKNode]
        let factor: CGFloat
        let span: CGFloat
    }

    private var layers: [Layer] = []
    private var viewSize = CGSize.zero

    func build(for size: CGSize) {
        removeAllChildren()
        layers.removeAll()
        viewSize = size

        let gradient = SKSpriteNode(texture: Textures.shared.backgroundGradient,
                                    size: CGSize(width: size.width + 60, height: size.height + 60))
        addChild(gradient)

        addLayer(factor: 0.05, span: size.height * 1.6, z: 1, seed: 21, populate: Backdrop.nebulae)
        addLayer(factor: 0.03, span: size.height, z: 2, seed: 31,
                 populate: Backdrop.stars(count: 120, sizes: 0.8...1.7, alphas: 0.3...0.75, twinkle: 0.3, halo: false))
        addLayer(factor: 0.1, span: size.height, z: 3, seed: 41,
                 populate: Backdrop.stars(count: 55, sizes: 1.3...2.3, alphas: 0.45...0.9, twinkle: 0.25, halo: false))
        addLayer(factor: 0.22, span: size.height, z: 4, seed: 51,
                 populate: Backdrop.stars(count: 16, sizes: 2...3.2, alphas: 0.7...1, twinkle: 0.4, halo: true))
    }

    func update(cameraBottom: CGFloat) {
        let bottom = -viewSize.height / 2
        for layer in layers {
            var offset = (cameraBottom * layer.factor).truncatingRemainder(dividingBy: layer.span)
            if offset < 0 { offset += layer.span }
            layer.tiles[0].position.y = bottom - offset
            layer.tiles[1].position.y = bottom - offset + layer.span
        }
    }

    private func addLayer(factor: CGFloat, span: CGFloat, z: CGFloat, seed: UInt64,
                          populate: (SKNode, CGFloat, inout SplitMix64) -> Void) {
        let tiles = (0..<2).map { _ -> SKNode in
            let tile = SKNode()
            tile.zPosition = z
            var rng = SplitMix64(seed: seed)
            populate(tile, span, &rng)
            addChild(tile)
            return tile
        }
        layers.append(Layer(tiles: tiles, factor: factor, span: span))
    }

    private static func nebulae(tile: SKNode, span: CGFloat, rng: inout SplitMix64) {
        for index in 0..<4 {
            let size = CGFloat.random(in: 280...460, using: &rng)
            let cloud = SKSpriteNode(texture: Textures.shared.nebulae[index % 3],
                                     size: CGSize(width: size, height: size * .random(in: 0.7...1.1, using: &rng)))
            // Keep each cloud inside its own tile so the wrap-around never pops.
            let reach = size * 0.56
            cloud.position = CGPoint(x: .random(in: -180...180, using: &rng),
                                     y: .random(in: reach...max(reach, span - reach), using: &rng))
            cloud.zRotation = .random(in: 0...(2 * .pi), using: &rng)
            cloud.color = Theme.nebulaTints.randomElement(using: &rng) ?? Theme.violet
            cloud.colorBlendFactor = 1
            cloud.alpha = .random(in: 0.16...0.3, using: &rng)
            cloud.blendMode = .add
            tile.addChild(cloud)
        }
    }

    private static func stars(count: Int, sizes: ClosedRange<CGFloat>, alphas: ClosedRange<CGFloat>,
                              twinkle: Double, halo: Bool) -> (SKNode, CGFloat, inout SplitMix64) -> Void {
        { tile, span, rng in
            for _ in 0..<count {
                let star = SKSpriteNode(texture: Textures.shared.dot)
                let side = CGFloat.random(in: sizes, using: &rng)
                let alpha = CGFloat.random(in: alphas, using: &rng)
                star.size = CGSize(width: side, height: side)
                star.position = CGPoint(x: .random(in: -205...205, using: &rng), y: .random(in: 2...(span - 2), using: &rng))
                star.color = Theme.starTints.randomElement(using: &rng) ?? .white
                star.colorBlendFactor = 1
                star.alpha = alpha
                star.blendMode = .add
                if halo {
                    let glow = SKSpriteNode(texture: Textures.shared.softGlow, size: CGSize(width: side * 5, height: side * 5))
                    glow.color = star.color
                    glow.colorBlendFactor = 1
                    glow.alpha = 0.35
                    glow.blendMode = .add
                    star.addChild(glow)
                }
                if Double.random(in: 0..<1, using: &rng) < twinkle {
                    let duration = Double.random(in: 0.8...2.6, using: &rng)
                    star.run(.repeatForever(.sequence([
                        .fadeAlpha(to: alpha * 0.25, duration: duration),
                        .fadeAlpha(to: alpha, duration: duration),
                    ])))
                }
                tile.addChild(star)
            }
        }
    }
}

// MARK: - Effects

enum Effects {
    static func explosion() -> SKEmitterNode {
        let burst = SKEmitterNode()
        burst.particleTexture = Textures.shared.softGlow
        burst.particleBirthRate = 4000
        burst.numParticlesToEmit = 140
        burst.particleLifetime = 0.9
        burst.particleLifetimeRange = 0.5
        burst.particleSpeed = 170
        burst.particleSpeedRange = 150
        burst.emissionAngleRange = .pi * 2
        burst.particleScale = 0.07
        burst.particleScaleRange = 0.05
        burst.particleScaleSpeed = -0.06
        burst.particleAlphaSpeed = -1.1
        burst.particleColorBlendFactor = 1
        burst.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [UIColor.white, Theme.gold, Theme.magenta, Theme.violet],
            times: [0, 0.15, 0.5, 1])
        burst.particleBlendMode = .add
        burst.zPosition = 25
        return burst
    }

    static func shockwave(at point: CGPoint) -> SKNode {
        let ring = SKShapeNode(circleOfRadius: 10)
        ring.position = point
        ring.strokeColor = .white
        ring.lineWidth = 2.5
        ring.blendMode = .add
        ring.zPosition = 26
        ring.run(.sequence([
            .group([.scale(to: 9, duration: 0.55), .fadeOut(withDuration: 0.55)]),
            .removeFromParent(),
        ]))
        return ring
    }
}
