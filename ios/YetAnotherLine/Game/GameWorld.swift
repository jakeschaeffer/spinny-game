import CoreGraphics
import Foundation

/// Small, fast, seedable RNG so a run (and the autopilot's look-ahead) is reproducible.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum PlanetStyle: Int, CaseIterable {
    case rocky, gasGiant, ice, star
}

struct Planet: Identifiable, Equatable {
    let id: Int
    let position: CGPoint
    let radius: CGFloat
    let style: PlanetStyle
    let palette: Int
    /// Tilt of the decorative ring, or nil for a ringless planet. Rings never collide.
    let ringTilt: CGFloat?

    var hookRadius: CGFloat { radius * GameWorld.Tuning.hookReachPerRadius }
}

enum DeathCause: Equatable {
    case planet(Int), wall, fell
}

/// The feel of the game, adjustable from Settings. Every value is relative to the stock tuning.
struct Physics: Codable, Equatable {
    /// Multiplier on how fast the comet whips around a planet.
    var spin: CGFloat = 1
    /// How much tether length changes the spin: at 0 every tether spins at the same rate; at 1 spin
    /// slows in direct proportion to length (the original web game). In between, short tethers whip
    /// around faster and long ones swing only a little slower.
    var tetherEffect: CGFloat = 0.6
    /// Multiplier on launch speed.
    var launchPower: CGFloat = 1
    /// Multiplier on gravity; 0 turns it off.
    var gravity: CGFloat = 1
    /// Real seconds you get to grab a planet again after letting go while your swing is out of
    /// bounds, before it counts as a crash. 0 means an out-of-bounds release crashes immediately.
    var regrabWindow: TimeInterval = 0.1
}

extension Physics {
    /// Tolerates settings saved by older versions: any value missing from the data keeps its default.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Physics()
        self.init(
            spin: try container.decodeIfPresent(CGFloat.self, forKey: .spin) ?? defaults.spin,
            tetherEffect: try container.decodeIfPresent(CGFloat.self, forKey: .tetherEffect) ?? defaults.tetherEffect,
            launchPower: try container.decodeIfPresent(CGFloat.self, forKey: .launchPower) ?? defaults.launchPower,
            gravity: try container.decodeIfPresent(CGFloat.self, forKey: .gravity) ?? defaults.gravity,
            regrabWindow: try container.decodeIfPresent(TimeInterval.self, forKey: .regrabWindow) ?? defaults.regrabWindow)
    }
}

enum WorldEvent: Equatable {
    case hooked(planetID: Int, combo: Int)
    case launched(speed: CGFloat)
    case died(DeathCause)
}

/// The whole simulation, free of any rendering. The scene feeds it input and time and draws the result.
///
/// Coordinates are y-up "world units". The playfield is 400 units wide (the size of the original web
/// game's board); its visible height follows the screen's aspect ratio.
struct GameWorld {
    enum Tuning {
        static let width: CGFloat = 400
        static let playerRadius: CGFloat = 6
        static let wallInset: CGFloat = 12
        static let startSpeed: CGFloat = 240
        static let launchSpeed: CGFloat = 330
        static let comboSpeedStep: CGFloat = 6
        static let comboSpeedCap: CGFloat = 60
        /// The fastest launch a big swing can fling you, relative to `launchSpeed`.
        static let maxFling: CGFloat = 1.35
        static let gravity: CGFloat = 54
        /// Radians per second on a tether `referenceTether` units long.
        static let spinRate: CGFloat = 3.8
        static let referenceTether: CGFloat = 100
        static let maxSpinRate: CGFloat = 12
        static let hookReachPerRadius: CGFloat = 180.0 / 16.0
        static let comboWindow: TimeInterval = 2
        static let gracePeriod: TimeInterval = 2
        static let unitsPerPoint: CGFloat = 8
        /// Where the player sits on screen, as a fraction of the view height from the bottom.
        static let cameraAnchor: CGFloat = 0.4
        static let cameraStiffness: CGFloat = 6.3
        static let fallMargin: CGFloat = 80
        static let radiusRange: ClosedRange<CGFloat> = 13...32
        static let rowGap: ClosedRange<CGFloat> = 72...108
        /// Gap (beyond both radii) that spawning tries to keep between neighbouring planets.
        static let preferredClearance: CGFloat = 48
        /// Planets reaching below this height stay out of the straight-up launch path.
        static let launchLaneHeight: CGFloat = 560
        static let paletteCount = 8
        static let fixedStep: TimeInterval = 1.0 / 240.0
    }

    var viewHeight: CGFloat
    var physics: Physics
    var spawnsPlanets = true
    /// How fast world time runs relative to real time (the game speed setting). Only used to keep the
    /// regrab window in real time.
    var timeScale: Double = 1

    private(set) var player: CGPoint
    private(set) var velocity: CGVector
    /// World y of the bottom edge of the visible area.
    private(set) var cameraBottom: CGFloat
    private(set) var planets: [Planet] = []
    private(set) var hookedID: Int?
    private(set) var hookAngle: CGFloat = 0
    private(set) var hookDistance: CGFloat = 0
    private(set) var spinDirection: CGFloat = 1
    private(set) var isHolding = false
    private(set) var time: TimeInterval = 0
    private(set) var combo = 0
    private(set) var bestCombo = 0
    private(set) var lastHookTime: TimeInterval = -.infinity
    private(set) var maxAltitude: CGFloat = 0
    private(set) var deathCause: DeathCause?
    /// Real seconds left to grab again after an out-of-bounds release; bounds are forgiven meanwhile.
    private(set) var regrabRemaining: TimeInterval?

    private var rng: SplitMix64
    private var nextRowY: CGFloat = 90
    private var nextID = 1

    init(viewHeight: CGFloat, seed: UInt64, physics: Physics = Physics()) {
        self.viewHeight = viewHeight
        self.physics = physics
        rng = SplitMix64(seed: seed)
        player = CGPoint(x: Tuning.width / 2, y: 0)
        velocity = CGVector(dx: 0, dy: Tuning.startSpeed)
        cameraBottom = -viewHeight * Tuning.cameraAnchor
        spawnAhead()
    }

    /// A hand-built world for tests: fixed planets, nothing spawns, and the grace period can be skipped.
    init(viewHeight: CGFloat, player: CGPoint, velocity: CGVector, planets: [Planet],
         physics: Physics = Physics(gravity: 0), skipGrace: Bool = true) {
        self.viewHeight = viewHeight
        self.physics = physics
        rng = SplitMix64(seed: 0)
        self.player = player
        self.velocity = velocity
        self.planets = planets
        cameraBottom = player.y - viewHeight * Tuning.cameraAnchor
        maxAltitude = max(0, player.y)
        spawnsPlanets = false
        if skipGrace { time = Tuning.gracePeriod }
    }

    var isDead: Bool { deathCause != nil }
    var inGrace: Bool { time < Tuning.gracePeriod }
    var score: Int { Int(maxAltitude / Tuning.unitsPerPoint) }
    var cameraCenterY: CGFloat { cameraBottom + viewHeight / 2 }
    var isOrbiting: Bool { isHolding && hookedID != nil }
    var hookedPlanet: Planet? { hookedID.flatMap { id in planets.first { $0.id == id } } }
    var speed: CGFloat { hypot(velocity.dx, velocity.dy) }

    /// Angular speed around a planet: shorter tethers whip around faster.
    func spinRate(tether: CGFloat) -> CGFloat {
        let ratio = Tuning.referenceTether / max(tether, 20)
        return min(Tuning.spinRate * physics.spin * pow(ratio, physics.tetherEffect), Tuning.maxSpinRate)
    }

    /// The combo worth showing right now: it lapses once the window since the last hook runs out.
    var liveCombo: Int { isOrbiting || time - lastHookTime < Tuning.comboWindow ? combo : 0 }

    func nearestHookable() -> Planet? {
        var best: Planet?
        var bestDistance = CGFloat.infinity
        for planet in planets {
            let distance = player.distance(to: planet.position)
            if distance < planet.hookRadius && distance < bestDistance {
                best = planet
                bestDistance = distance
            }
        }
        return best
    }

    // MARK: Input

    mutating func press() -> [WorldEvent] {
        guard !isDead, !isHolding else { return [] }
        isHolding = true
        guard let target = nearestHookable() else { return [] }

        let dx = player.x - target.position.x
        let dy = player.y - target.position.y
        hookedID = target.id
        regrabRemaining = nil
        hookAngle = atan2(dy, dx)
        hookDistance = hypot(dx, dy)
        // Keep spinning the way the player was already travelling around the planet.
        let cross = dx * velocity.dy - dy * velocity.dx
        spinDirection = cross < 0 ? -1 : 1

        combo = time - lastHookTime < Tuning.comboWindow ? combo + 1 : 1
        bestCombo = max(bestCombo, combo)
        lastHookTime = time
        return [.hooked(planetID: target.id, combo: combo)]
    }

    mutating func release() -> [WorldEvent] {
        guard isHolding else { return [] }
        isHolding = false
        guard hookedID != nil, !isDead else {
            hookedID = nil
            return []
        }
        hookedID = nil
        // Letting go past a wall (or below the screen) isn't fatal straight away: there's a short
        // window to grab again.
        if boundsViolation() != nil, physics.regrabWindow > 0 {
            regrabRemaining = physics.regrabWindow
        }
        // Fling: carry the swing's speed off the planet, never slower than a standard launch and
        // capped so a huge orbit can't fire you across the screen.
        let orbitalSpeed = spinRate(tether: hookDistance) * hookDistance
        let fling = min(max(orbitalSpeed, Tuning.launchSpeed), Tuning.launchSpeed * Tuning.maxFling)
        let comboBonus = min(CGFloat(combo) * Tuning.comboSpeedStep, Tuning.comboSpeedCap)
        let launch = (fling + comboBonus) * physics.launchPower
        let angle = hookAngle + spinDirection * .pi / 2
        velocity = CGVector(dx: cos(angle) * launch, dy: sin(angle) * launch)
        return [.launched(speed: launch)]
    }

    // MARK: Simulation

    mutating func step(_ dt: TimeInterval) -> [WorldEvent] {
        guard !isDead else { return [] }
        time += dt
        let h = CGFloat(dt)

        if isOrbiting, let planet = hookedPlanet {
            let omega = spinRate(tether: hookDistance) * spinDirection
            hookAngle += omega * h
            player = CGPoint(x: planet.position.x + cos(hookAngle) * hookDistance,
                             y: planet.position.y + sin(hookAngle) * hookDistance)
            let tangentSpeed = omega * hookDistance
            velocity = CGVector(dx: -sin(hookAngle) * tangentSpeed, dy: cos(hookAngle) * tangentSpeed)
        } else {
            velocity.dy -= Tuning.gravity * physics.gravity * h
            player = CGPoint(x: player.x + velocity.dx * h, y: player.y + velocity.dy * h)
        }
        if let remaining = regrabRemaining {
            let left = remaining - dt / max(timeScale, 0.01)
            regrabRemaining = left > 0 ? left : nil
        }

        if let cause = collision() {
            deathCause = cause
            return [.died(cause)]
        }
        maxAltitude = max(maxAltitude, player.y)
        followCamera(dt)
        spawnAhead()
        cullBehind()
        return []
    }

    private func collision() -> DeathCause? {
        // The opening grace period only forgives planets; walls are solid from the first frame so a
        // crash always happens where you can see it.
        if !inGrace {
            for planet in planets where planet.id != hookedID {
                if player.distance(to: planet.position) < planet.radius + Tuning.playerRadius {
                    return .planet(planet.id)
                }
            }
        }
        // While orbiting you're tethered: the swing may cross the walls or dip off-screen safely.
        guard !isOrbiting, regrabRemaining == nil else { return nil }
        return boundsViolation()
    }

    private func boundsViolation() -> DeathCause? {
        if player.x < Tuning.wallInset || player.x > Tuning.width - Tuning.wallInset { return .wall }
        if player.y < cameraBottom - Tuning.fallMargin { return .fell }
        return nil
    }

    private mutating func followCamera(_ dt: TimeInterval) {
        // The camera only ever chases upward, so falling behind is fatal. While orbiting it may sink
        // just enough to keep the whole swing in view.
        var target = max(cameraBottom, player.y - viewHeight * Tuning.cameraAnchor)
        if isOrbiting, let planet = hookedPlanet {
            target = min(target, planet.position.y - hookDistance - 50)
        }
        let blend = 1 - exp(-Tuning.cameraStiffness * CGFloat(dt))
        cameraBottom += (target - cameraBottom) * blend
    }

    // MARK: Level generation

    private mutating func spawnAhead() {
        guard spawnsPlanets else { return }
        while nextRowY < cameraBottom + viewHeight + 420 {
            spawnPlanet(nearY: nextRowY)
            nextRowY += CGFloat.random(in: Tuning.rowGap, using: &rng)
        }
    }

    private mutating func spawnPlanet(nearY rowY: CGFloat) {
        let radius = CGFloat.random(in: Tuning.radiusRange, using: &rng)
        var chosen = CGPoint(x: Tuning.width / 2, y: rowY)
        var bestClearance = -CGFloat.infinity
        for _ in 0..<16 {
            let candidate = CGPoint(x: CGFloat.random(in: 50...(Tuning.width - 50), using: &rng),
                                    y: rowY + CGFloat.random(in: -14...14, using: &rng))
            let clearance = clearance(for: candidate, radius: radius)
            if clearance > bestClearance {
                bestClearance = clearance
                chosen = candidate
            }
            if clearance >= Tuning.preferredClearance { break }
        }

        let style = randomStyle()
        planets.append(Planet(id: nextID, position: chosen, radius: radius, style: style,
                              palette: randomPalette(for: style), ringTilt: randomRingTilt(for: style)))
        nextID += 1
    }

    private func clearance(for point: CGPoint, radius: CGFloat) -> CGFloat {
        var gap = CGFloat.infinity
        for other in planets where abs(other.position.y - point.y) < 260 {
            gap = min(gap, point.distance(to: other.position) - other.radius - radius)
        }
        if point.y - radius < Tuning.launchLaneHeight {
            gap = min(gap, abs(point.x - Tuning.width / 2) - radius - Tuning.playerRadius)
        }
        return gap
    }

    private mutating func randomStyle() -> PlanetStyle {
        switch Double.random(in: 0..<1, using: &rng) {
        case ..<0.36: .rocky
        case ..<0.66: .gasGiant
        case ..<0.86: .ice
        default: .star
        }
    }

    private mutating func randomPalette(for style: PlanetStyle) -> Int {
        let options: [Int] = switch style {
        case .star: [4, 5, 1]
        case .ice: [1, 2, 7]
        case .rocky, .gasGiant: Array(0..<Tuning.paletteCount)
        }
        return options.randomElement(using: &rng) ?? 0
    }

    private mutating func randomRingTilt(for style: PlanetStyle) -> CGFloat? {
        let chance = switch style {
        case .gasGiant: 0.45
        case .ice: 0.2
        case .rocky, .star: 0.0
        }
        guard Double.random(in: 0..<1, using: &rng) < chance else { return nil }
        return CGFloat.random(in: -0.45...0.45, using: &rng)
    }

    private mutating func cullBehind() {
        let limit = cameraBottom - 260
        planets.removeAll { $0.position.y + $0.radius < limit && $0.id != hookedID }
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
