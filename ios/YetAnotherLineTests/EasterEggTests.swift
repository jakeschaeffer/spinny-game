import CoreGraphics
import XCTest
@testable import YetAnotherLine

final class EasterEggTests: XCTestCase {
    func testTheUFOAppearsAt500() {
        XCTAssertEqual(EasterEgg.ufo.score, 500)
        XCTAssertEqual(EasterEgg.due(at: 499, shown: [.satellite]), [])
        XCTAssertEqual(EasterEgg.due(at: 500, shown: [.satellite]), [.ufo])
    }

    func testEachEggShowsOncePerRun() {
        var shown = Set<EasterEgg>()
        var seen: [EasterEgg] = []
        for score in stride(from: 0, through: 2500, by: 7) {
            for egg in EasterEgg.due(at: score, shown: shown) {
                shown.insert(egg)
                seen.append(egg)
            }
        }
        XCTAssertEqual(seen, EasterEgg.allCases, "each once, in height order")
    }

    func testEveryEggBuildsANodeThatCleansUpAfterItself() {
        for egg in EasterEgg.allCases {
            let node = egg.makeNode(visible: CGSize(width: 400, height: 869))
            XCTAssertTrue(node.hasActions(), "\(egg) should animate and then remove itself")
        }
    }
}
