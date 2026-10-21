import CoreGraphics
import XCTest
@testable import YetAnotherLine

final class TraceTests: XCTestCase {
    func testCloselySpacedPointsAreDropped() {
        var trace = Trace()
        trace.add(CGPoint(x: 200, y: 0))
        trace.add(CGPoint(x: 200, y: 1))
        trace.add(CGPoint(x: 200, y: 5))
        XCTAssertEqual(trace.points.count, 2)
    }

    func testBoundsAlwaysSpanThePlayfield() {
        var trace = Trace()
        trace.add(CGPoint(x: 180, y: 0))
        trace.add(CGPoint(x: 220, y: 900))
        XCTAssertEqual(trace.bounds, CGRect(x: 0, y: 0, width: GameWorld.Tuning.width, height: 900))

        trace.add(CGPoint(x: -40, y: 950))
        XCTAssertEqual(trace.bounds.minX, -40, "a swing past the wall widens the frame")
    }

    func testLatchingTheSamePlanetTwiceInARowCountsOnce() {
        let planet = Planet(id: 3, position: .zero, radius: 20, style: .rocky, palette: 0, ringTilt: nil)
        var trace = Trace()
        trace.latch(planet)
        trace.latch(planet)
        XCTAssertEqual(trace.latched.count, 1)
    }

    func testThePosterIsAPortraitStoryImage() {
        var trace = Trace()
        for step in 0..<400 { trace.add(CGPoint(x: 200 + 120 * sin(CGFloat(step) / 20), y: CGFloat(step) * 10)) }
        let poster = TracePoster.render(trace, score: 1234, mode: "ASTRO", bestCombo: 6)
        XCTAssertEqual(poster.size, TracePoster.size)
        XCTAssertEqual(poster.scale, 1)
    }
}
