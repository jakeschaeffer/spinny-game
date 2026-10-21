import UIKit

/// The picture shared from the end of a run: the whole line on a starfield, with the score.
enum TracePoster {
    static let size = CGSize(width: 1080, height: 1920)

    static func render(_ trace: Trace, score: Int, mode: String, bestCombo: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let ctx = context.cgContext
            drawBackground(ctx)
            drawHeader(score: score, mode: mode, bestCombo: bestCombo)
            drawLine(trace, in: CGRect(x: 90, y: 560, width: 900, height: 1240), ctx: ctx)
        }
    }

    private static func drawBackground(_ ctx: CGContext) {
        let colors = [UIColor(hex: 0x160B3A), UIColor(hex: 0x0A0A24), UIColor(hex: 0x03040B)].map(\.cgColor)
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.45, 1])!
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        var rng = SplitMix64(seed: 2026)
        for _ in 0..<260 {
            let side = CGFloat.random(in: 1.5...4.5, using: &rng)
            let point = CGPoint(x: .random(in: 0...size.width, using: &rng), y: .random(in: 0...size.height, using: &rng))
            let tint = Theme.starTints.randomElement(using: &rng) ?? .white
            ctx.setFillColor(tint.withAlphaComponent(.random(in: 0.2...0.8, using: &rng)).cgColor)
            ctx.fillEllipse(in: CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side))
        }
    }

    private static func drawHeader(score: Int, mode: String, bestCombo: Int) {
        func draw(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UIColor, kern: CGFloat, y: CGFloat) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size, weight: weight, width: .expanded),
                .foregroundColor: color,
                .kern: kern,
            ]
            let string = NSAttributedString(string: text, attributes: attributes)
            let width = string.size().width
            string.draw(at: CGPoint(x: (TracePoster.size.width - width) / 2, y: y))
        }
        draw("YET ANOTHER LINE", size: 34, weight: .bold, color: UIColor(white: 1, alpha: 0.7), kern: 10, y: 110)
        draw(score.formatted(), size: 190, weight: .black, color: .white, kern: 2, y: 170)
        let detail = bestCombo > 1 ? "\(mode) · ×\(bestCombo) COMBO" : mode
        draw(detail, size: 34, weight: .heavy, color: Theme.cyan, kern: 6, y: 430)
    }

    private static func drawLine(_ trace: Trace, in area: CGRect, ctx: CGContext) {
        guard trace.points.count > 1 else { return }
        let bounds = trace.bounds.insetBy(dx: -10, dy: -20)
        let k = min(area.width / bounds.width, area.height / bounds.height)
        let origin = CGPoint(x: area.midX - bounds.width * k / 2, y: area.midY + bounds.height * k / 2)
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + (point.x - bounds.minX) * k, y: origin.y - (point.y - bounds.minY) * k)
        }

        // The force-field walls, for scale.
        ctx.setStrokeColor(Theme.cyan.withAlphaComponent(0.22).cgColor)
        ctx.setLineWidth(2)
        for x in [GameWorld.Tuning.wallInset, GameWorld.Tuning.width - GameWorld.Tuning.wallInset] {
            ctx.strokeLineSegments(between: [map(CGPoint(x: x, y: bounds.minY)), map(CGPoint(x: x, y: bounds.maxY))])
        }

        for planet in trace.latched {
            let center = map(planet.position)
            let radius = max(planet.radius * k, 5)
            ctx.setFillColor(Theme.planetPalettes[planet.palette].main.withAlphaComponent(0.85).cgColor)
            ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }

        // The line itself, coloured like the comet's trail from its oldest end to its newest.
        let core = min(max(3 * k, 4), 10)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let points = trace.points.map(map)
        let segments = min(96, points.count - 1)
        for (width, alpha) in [(core * 4, 0.16), (core, 1.0)] {
            ctx.setLineWidth(width)
            for index in 0..<segments {
                let start = index * (points.count - 1) / segments
                let end = (index + 1) * (points.count - 1) / segments
                guard end > start else { continue }
                let fraction = CGFloat(index + 1) / CGFloat(segments)
                ctx.setStrokeColor(Theme.trailColor(at: fraction).withAlphaComponent(alpha).cgColor)
                ctx.addLines(between: Array(points[start...end]))
                ctx.strokePath()
            }
        }

        if let last = points.last {
            ctx.setFillColor(Theme.gold.cgColor)
            ctx.fillEllipse(in: CGRect(x: last.x - core * 1.6, y: last.y - core * 1.6, width: core * 3.2, height: core * 3.2))
        }
    }
}
