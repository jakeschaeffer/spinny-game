import CoreGraphics
import XCTest
@testable import OneMoreLine

final class GameWorldTests: XCTestCase {
    private let viewHeight: CGFloat = 869
    private let step = GameWorld.Tuning.fixedStep

    private func planet(_ id: Int, x: CGFloat, y: CGFloat, radius: CGFloat = 20) -> Planet {
        Planet(id: id, position: CGPoint(x: x, y: y), radius: radius, style: .rocky, palette: 0, ringTilt: nil)
    }

    private func run(_ world: inout GameWorld, seconds: TimeInterval) -> [WorldEvent] {
        var events: [WorldEvent] = []
        for _ in 0..<Int(seconds / step) where events.isEmpty {
            events = world.step(step)
        }
        return events
    }

    func testReleaseLaunchesAlongTheOrbitTangent() {
        let anchor = planet(1, x: 200, y: 100)
        var world = GameWorld(viewHeight: viewHeight, player: CGPoint(x: 280, y: 100),
                              velocity: CGVector(dx: 0, dy: 240), planets: [anchor])

        XCTAssertEqual(world.press(), [.hooked(planetID: 1, combo: 1)])
        XCTAssertEqual(run(&world, seconds: 0.125), [])
        XCTAssertEqual(world.player.distance(to: anchor.position), 80, accuracy: 0.001)

        guard case let .launched(speed)? = world.release().first else { return XCTFail("expected a launch") }
        let radial = CGVector(dx: world.player.x - 200, dy: world.player.y - 100)
        let dot = radial.dx * world.velocity.dx + radial.dy * world.velocity.dy
        XCTAssertEqual(dot / (80 * speed), 0, accuracy: 1e-6, "launch should be perpendicular to the tether")
        XCTAssertEqual(world.speed, speed, accuracy: 1e-6)
        XCTAssertLessThan(world.velocity.dx, 0, "moving up on the right of the planet spins counter-clockwise")
    }

    func testShortTethersWhipAroundFasterAndBigSwingsFlingHarder() {
        let world = GameWorld(viewHeight: viewHeight, player: .zero, velocity: .zero, planets: [])
        XCTAssertGreaterThan(world.spinRate(tether: 30), world.spinRate(tether: 60))
        XCTAssertGreaterThan(world.spinRate(tether: 60), world.spinRate(tether: 150))
        XCTAssertGreaterThan(world.spinRate(tether: 200) / world.spinRate(tether: 100), 0.6,
                             "long tethers should only swing a little slower")

        func launchSpeed(tether: CGFloat) -> CGFloat {
            var world = GameWorld(viewHeight: viewHeight, player: CGPoint(x: 200 + tether, y: 0),
                                  velocity: CGVector(dx: 0, dy: 240), planets: [planet(1, x: 200, y: 0, radius: 25)])
            _ = world.press()
            _ = world.release()
            return world.speed
        }
        let comboBonus = GameWorld.Tuning.comboSpeedStep
        XCTAssertEqual(launchSpeed(tether: 40), GameWorld.Tuning.launchSpeed + comboBonus, accuracy: 0.01,
                       "tight spins still launch at full speed")
        XCTAssertGreaterThan(launchSpeed(tether: 120), launchSpeed(tether: 60))
        XCTAssertEqual(launchSpeed(tether: 250), GameWorld.Tuning.launchSpeed * GameWorld.Tuning.maxFling + comboBonus,
                       accuracy: 0.01, "the fling is capped")
    }

    func testQuickRehooksBuildACombo() {
        var world = GameWorld(viewHeight: viewHeight, player: CGPoint(x: 280, y: 100), velocity: CGVector(dx: 0, dy: 240),
                              planets: [planet(1, x: 200, y: 100), planet(2, x: 200, y: 400)])
        XCTAssertEqual(world.press(), [.hooked(planetID: 1, combo: 1)])
        _ = world.release()
        XCTAssertEqual(run(&world, seconds: 0.5), [])
        XCTAssertEqual(world.press(), [.hooked(planetID: 2, combo: 2)])
        XCTAssertEqual(world.liveCombo, 2)
    }

    func testComboLapsesAfterTheWindow() {
        var world = GameWorld(viewHeight: viewHeight, player: CGPoint(x: 280, y: 100), velocity: CGVector(dx: 0, dy: 240),
                              planets: [planet(1, x: 200, y: 100)])
        _ = world.press()
        XCTAssertEqual(run(&world, seconds: 2.5), [], "orbiting is safe")
        _ = world.release()
        XCTAssertEqual(world.press(), [.hooked(planetID: 1, combo: 1)])
    }

    func testHittingAWallInFreeFlightIsFatal() {
        var world = GameWorld(viewHeight: viewHeight, player: CGPoint(x: 30, y: 0),
                              velocity: CGVector(dx: -200, dy: 0), planets: [])
        XCTAssertEqual(run(&world, seconds: 1), [.died(.wall)])
    }

    func testWallsAreSolidEvenDuringTheOpeningGracePeriod() {
        var world = GameWorld(viewHeight: viewHeight, player: CGPoint(x: 30, y: 0),
                              velocity: CGVector(dx: -200, dy: 0), planets: [], skipGrace: false)
        XCTAssertTrue(world.inGrace)
        XCTAssertEqual(run(&world, seconds: 0.5), [.died(.wall)])
    }

    func testOrbitsMayCrossTheWalls() {
        var world = GameWorld(viewHeight: viewHeight, player: CGPoint(x: 100, y: 0),
                              velocity: CGVector(dx: 0, dy: 240), planets: [planet(1, x: 40, y: 0, radius: 15)])
        _ = world.press()
        XCTAssertEqual(run(&world, seconds: 1.3), [], "a full swing past x < 0 while tethered is fine")
    }

    func testOrbitingIntoAnotherPlanetIsFatal() {
        var world = GameWorld(viewHeight: viewHeight, player: CGPoint(x: 100, y: 0), velocity: CGVector(dx: 0, dy: 240),
                              planets: [planet(1, x: 40, y: 0, radius: 15), planet(2, x: 40, y: 60, radius: 10)])
        XCTAssertEqual(world.press(), [.hooked(planetID: 1, combo: 1)])
        XCTAssertEqual(run(&world, seconds: 1), [.died(.planet(2))])
    }

    func testFallingOffTheBottomEndsTheRun() {
        var world = GameWorld(viewHeight: viewHeight, seed: 7)
        XCTAssertEqual(run(&world, seconds: 30), [.died(.fell)], "the launch lane is clear, so an idle comet falls")
        XCTAssertGreaterThan(world.score, 50)
    }

    func testGeneratedPlanetsNeverCrowdTheLaunchLane() {
        for seed in UInt64(1)...25 {
            let world = GameWorld(viewHeight: viewHeight, seed: seed)
            for planet in world.planets where planet.position.y - planet.radius < GameWorld.Tuning.launchLaneHeight {
                XCTAssertGreaterThan(abs(planet.position.x - 200), planet.radius + GameWorld.Tuning.playerRadius,
                                     "seed \(seed) planet \(planet.id)")
            }
        }
    }

    /// Plays whole runs with the autopilot: a smoke test that levels stay flyable and the rules hang together.
    func testAutopilotClimbsAndPlanetsLeaveRoomToFly() {
        var scores: [Int] = []
        var tightestGap = CGFloat.infinity
        for seed in UInt64(1)...12 {
            var world = GameWorld(viewHeight: viewHeight, seed: seed)
            var seen: [Int: Planet] = [:]
            var ticks = 0
            while !world.isDead, Double(ticks) * step < 40 {
                if ticks.isMultiple(of: 4) {
                    let wantsHold = world.autopilotWantsHold()
                    if wantsHold != world.isHolding { _ = wantsHold ? world.press() : world.release() }
                    for planet in world.planets { seen[planet.id] = planet }
                }
                _ = world.step(step)
                ticks += 1
            }
            scores.append(world.score)

            let planets = Array(seen.values)
            for (i, a) in planets.enumerated() {
                for b in planets[(i + 1)...] {
                    tightestGap = min(tightestGap, a.position.distance(to: b.position) - a.radius - b.radius)
                }
            }
        }
        let median = scores.sorted()[scores.count / 2]
        XCTAssertGreaterThan(median, 500, "scores: \(scores)")
        XCTAssertGreaterThan(tightestGap, GameWorld.Tuning.playerRadius * 2 + 10)
    }
}
