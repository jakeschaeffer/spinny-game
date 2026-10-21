import CoreGraphics

/// The whole line of one run, kept for the end-of-run view and the share picture. World units, y up.
struct Trace: Equatable {
    /// Points closer together than this are dropped; plenty for drawing, and keeps long runs light.
    static let spacing: CGFloat = 3

    private(set) var points: [CGPoint] = []
    /// Planets latched onto, in order.
    private(set) var latched: [Planet] = []

    mutating func add(_ point: CGPoint) {
        if let last = points.last, last.distance(to: point) < Trace.spacing { return }
        points.append(point)
    }

    mutating func latch(_ planet: Planet) {
        if latched.last?.id != planet.id { latched.append(planet) }
    }

    /// The path's extent, always including the full playfield width so every picture shares a frame.
    var bounds: CGRect {
        var minX: CGFloat = 0, maxX = GameWorld.Tuning.width
        var minY = points.first?.y ?? 0, maxY = minY
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
