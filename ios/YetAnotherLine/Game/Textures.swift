import SpriteKit
import UIKit

/// Every texture in the game is drawn procedurally at launch, so there are no image assets to manage.
final class Textures {
    static let shared = Textures()

    /// Soft radial falloff, tinted and additively blended for glows, particles and halos.
    let softGlow: SKTexture
    /// Small crisp disc for stars and the comet's core.
    let dot: SKTexture
    let backgroundGradient: SKTexture
    /// Horizontal glow profile, stretched vertically for the force-field walls.
    let wall: SKTexture
    let nebulae: [SKTexture]
    /// Far half of a planetary ring (drawn behind the planet) and near half (drawn in front).
    let ringBack: SKTexture
    let ringFront: SKTexture

    private var planetCache: [Int: SKTexture] = [:]

    private init() {
        softGlow = Textures.render(CGSize(width: 128, height: 128)) { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            Textures.radial(ctx, center: c, radius: size.width / 2, stops: [
                (0, UIColor(white: 1, alpha: 1)), (0.12, UIColor(white: 1, alpha: 0.8)),
                (0.3, UIColor(white: 1, alpha: 0.38)), (0.55, UIColor(white: 1, alpha: 0.12)),
                (0.8, UIColor(white: 1, alpha: 0.03)), (1, UIColor(white: 1, alpha: 0)),
            ])
        }

        dot = Textures.render(CGSize(width: 32, height: 32)) { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            Textures.radial(ctx, center: c, radius: size.width / 2, stops: [
                (0, UIColor(white: 1, alpha: 1)), (0.72, UIColor(white: 1, alpha: 1)), (1, UIColor(white: 1, alpha: 0)),
            ])
        }

        backgroundGradient = Textures.render(CGSize(width: 8, height: 512)) { ctx, size in
            let colors = [UIColor(hex: 0x160B3A), UIColor(hex: 0x0A0A24), UIColor(hex: 0x03040B)].map(\.cgColor)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray,
                                      locations: [0, 0.45, 1])!
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }

        wall = Textures.render(CGSize(width: 64, height: 4)) { ctx, size in
            let white = { (a: CGFloat) in UIColor(white: 1, alpha: a).cgColor }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [white(0), white(0.18), white(0.55), white(1), white(0.55), white(0.18), white(0)] as CFArray,
                                      locations: [0, 0.3, 0.44, 0.5, 0.56, 0.7, 1])!
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: 0), options: [])
        }

        nebulae = (0..<3).map { variant in
            Textures.render(CGSize(width: 256, height: 256)) { ctx, size in
                var rng = SplitMix64(seed: UInt64(variant + 11) &* 104_729)
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for _ in 0..<22 {
                    let angle = CGFloat.random(in: 0...(2 * .pi), using: &rng)
                    let distance = CGFloat.random(in: 0...(size.width * 0.18), using: &rng)
                    let center = CGPoint(x: c.x + cos(angle) * distance, y: c.y + sin(angle) * distance)
                    let radius = size.width * CGFloat.random(in: 0.12...0.3, using: &rng)
                    let alpha = CGFloat.random(in: 0.1...0.22, using: &rng)
                    Textures.radial(ctx, center: center, radius: radius, stops: [
                        (0, UIColor(white: 1, alpha: alpha)), (1, UIColor(white: 1, alpha: 0)),
                    ])
                }
            }
        }

        ringBack = Textures.ring(nearHalf: false)
        ringFront = Textures.ring(nearHalf: true)
    }

    func planet(style: PlanetStyle, palette: Int) -> SKTexture {
        let key = palette * 10 + style.rawValue
        if let cached = planetCache[key] { return cached }
        let texture = Textures.renderPlanet(style: style, palette: Theme.planetPalettes[palette], seed: UInt64(key + 1))
        planetCache[key] = texture
        return texture
    }

    func prewarm() {
        for style in PlanetStyle.allCases {
            for palette in Theme.planetPalettes.indices { _ = planet(style: style, palette: palette) }
        }
    }

    // MARK: Drawing helpers

    private static func render(_ size: CGSize, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext, size) }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    private static func radial(_ ctx: CGContext, center: CGPoint, radius: CGFloat,
                               stops: [(CGFloat, UIColor)], from startCenter: CGPoint? = nil) {
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: stops.map(\.1.cgColor) as CFArray,
                                  locations: stops.map(\.0))!
        ctx.drawRadialGradient(gradient, startCenter: startCenter ?? center, startRadius: 0,
                               endCenter: center, endRadius: radius, options: [.drawsAfterEndLocation])
    }

    private static func ring(nearHalf: Bool) -> SKTexture {
        let full = CGSize(width: 512, height: 160)
        return render(CGSize(width: full.width, height: full.height / 2)) { ctx, _ in
            // UIKit draws y-down: the top half of the ellipse is the far side of the ring.
            if nearHalf { ctx.translateBy(x: 0, y: -full.height / 2) }
            let bands: [(CGFloat, CGFloat)] = [(0.64, 0.2), (0.7, 0.42), (0.76, 0.28), (0.83, 0.55), (0.9, 0.34), (0.96, 0.16)]
            ctx.setLineWidth(12)
            for (scale, alpha) in bands {
                let rx = (full.width / 2 - 8) * scale
                let ry = (full.height / 2 - 4) * scale
                ctx.setStrokeColor(UIColor(white: 1, alpha: alpha).cgColor)
                ctx.strokeEllipse(in: CGRect(x: full.width / 2 - rx, y: full.height / 2 - ry, width: rx * 2, height: ry * 2))
            }
        }
    }

    private static func renderPlanet(style: PlanetStyle, palette: PlanetPalette, seed: UInt64) -> SKTexture {
        render(CGSize(width: 256, height: 256)) { ctx, size in
            var rng = SplitMix64(seed: seed &* 7919)
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3)
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let r = rect.width / 2
            let lightSource = CGPoint(x: c.x - r * 0.38, y: c.y - r * 0.38)

            ctx.saveGState()
            ctx.addEllipse(in: rect)
            ctx.clip()

            if style == .star {
                radial(ctx, center: c, radius: r, stops: [
                    (0, .white), (0.35, palette.light), (0.85, palette.main), (1, palette.dark),
                ])
                for _ in 0..<140 {
                    let angle = CGFloat.random(in: 0...(2 * .pi), using: &rng)
                    let distance = sqrt(CGFloat.random(in: 0...1, using: &rng)) * r * 0.95
                    let size = r * CGFloat.random(in: 0.02...0.05, using: &rng)
                    ctx.setFillColor(UIColor(white: 1, alpha: .random(in: 0.06...0.14, using: &rng)).cgColor)
                    ctx.fillEllipse(in: CGRect(x: c.x + cos(angle) * distance - size, y: c.y + sin(angle) * distance - size,
                                               width: size * 2, height: size * 2))
                }
                radial(ctx, center: c, radius: r, stops: [
                    (0, palette.dark.withAlphaComponent(0)), (0.6, palette.dark.withAlphaComponent(0)),
                    (1, palette.dark.withAlphaComponent(0.55)),
                ])
                ctx.restoreGState()
                return
            }

            radial(ctx, center: c, radius: r * 1.1, stops: [
                (0, palette.light), (0.5, palette.main), (1, palette.dark),
            ], from: lightSource)

            switch style {
            case .rocky: drawCraters(ctx, center: c, radius: r, palette: palette, rng: &rng)
            case .gasGiant: drawBands(ctx, rect: rect, radius: r, palette: palette, rng: &rng)
            case .ice: drawIce(ctx, rect: rect, center: c, radius: r, rng: &rng)
            case .star: break
            }

            // Thin bright atmosphere at the rim, then the night side on the far edge.
            ctx.setStrokeColor(palette.light.withAlphaComponent(0.45).cgColor)
            ctx.setLineWidth(r * 0.07)
            ctx.strokeEllipse(in: rect.insetBy(dx: r * 0.02, dy: r * 0.02))
            let black = { (a: CGFloat) in UIColor(white: 0, alpha: a) }
            radial(ctx, center: lightSource, radius: r * 2.05, stops: [
                (0, black(0)), (0.3, black(0.05)), (0.55, black(0.35)), (0.75, black(0.78)), (1, black(0.92)),
            ])
            ctx.restoreGState()
        }
    }

    private static func drawCraters(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat,
                                    palette: PlanetPalette, rng: inout SplitMix64) {
        for _ in 0..<6 {
            let angle = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            let distance = CGFloat.random(in: 0...(r * 0.7), using: &rng)
            let size = r * CGFloat.random(in: 0.25...0.5, using: &rng)
            let color = Bool.random(using: &rng) ? palette.dark : palette.light
            ctx.setFillColor(color.withAlphaComponent(0.14).cgColor)
            ctx.fillEllipse(in: CGRect(x: c.x + cos(angle) * distance - size, y: c.y + sin(angle) * distance - size * 0.8,
                                       width: size * 2, height: size * 1.6))
        }
        for _ in 0..<11 {
            let angle = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            let distance = CGFloat.random(in: 0...(r * 0.85), using: &rng)
            let size = r * CGFloat.random(in: 0.05...0.19, using: &rng)
            let p = CGPoint(x: c.x + cos(angle) * distance, y: c.y + sin(angle) * distance)
            ctx.setFillColor(palette.dark.withAlphaComponent(0.4).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - size, y: p.y - size, width: size * 2, height: size * 2))
            // Light falls from the upper left, so the crater's lower-right wall catches it.
            ctx.setStrokeColor(palette.light.withAlphaComponent(0.35).cgColor)
            ctx.setLineWidth(size * 0.2)
            ctx.addArc(center: p, radius: size * 0.9, startAngle: -0.2, endAngle: .pi * 0.7, clockwise: false)
            ctx.strokePath()
        }
    }

    private static func drawBands(_ ctx: CGContext, rect: CGRect, radius r: CGFloat,
                                  palette: PlanetPalette, rng: inout SplitMix64) {
        var y = rect.minY
        var lightBand = Bool.random(using: &rng)
        while y < rect.maxY {
            let height = r * CGFloat.random(in: 0.07...0.2, using: &rng)
            let color = (lightBand ? palette.light : palette.dark).withAlphaComponent(.random(in: 0.18...0.42, using: &rng))
            let wave = r * CGFloat.random(in: 0.01...0.035, using: &rng)
            let phase = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            let offset = { (x: CGFloat) in sin((x - rect.minX) / rect.width * 3 * .pi + phase) * wave }

            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.minX, y: y + offset(rect.minX)))
            for x in stride(from: rect.minX, through: rect.maxX, by: 8) { path.addLine(to: CGPoint(x: x, y: y + offset(x))) }
            for x in stride(from: rect.maxX, through: rect.minX, by: -8) { path.addLine(to: CGPoint(x: x, y: y + height + offset(x))) }
            path.closeSubpath()
            ctx.addPath(path)
            ctx.setFillColor(color.cgColor)
            ctx.fillPath()

            y += height
            lightBand.toggle()
        }
        if Bool.random(using: &rng) {
            let storm = CGRect(x: rect.midX + r * CGFloat.random(in: -0.4...0.1, using: &rng),
                               y: rect.midY + r * CGFloat.random(in: -0.1...0.4, using: &rng),
                               width: r * 0.36, height: r * 0.18)
            ctx.setFillColor(palette.light.withAlphaComponent(0.5).cgColor)
            ctx.fillEllipse(in: storm)
            ctx.setFillColor(palette.dark.withAlphaComponent(0.3).cgColor)
            ctx.fillEllipse(in: storm.insetBy(dx: storm.width * 0.25, dy: storm.height * 0.25))
        }
    }

    private static func drawIce(_ ctx: CGContext, rect: CGRect, center c: CGPoint, radius r: CGFloat,
                                rng: inout SplitMix64) {
        ctx.setFillColor(UIColor(white: 1, alpha: 0.55).cgColor)
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.75, y: rect.minY - r * 0.28, width: r * 1.5, height: r * 0.6))
        ctx.setFillColor(UIColor(white: 1, alpha: 0.4).cgColor)
        ctx.fillEllipse(in: CGRect(x: c.x - r * 0.55, y: rect.maxY - r * 0.22, width: r * 1.1, height: r * 0.4))
        ctx.setLineCap(.round)
        for _ in 0..<7 {
            let center = CGPoint(x: c.x + r * CGFloat.random(in: -0.6...0.6, using: &rng),
                                 y: c.y + r * CGFloat.random(in: -0.5...0.5, using: &rng))
            let start = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            ctx.setStrokeColor(UIColor(white: 1, alpha: .random(in: 0.12...0.28, using: &rng)).cgColor)
            ctx.setLineWidth(r * CGFloat.random(in: 0.04...0.09, using: &rng))
            ctx.addArc(center: center, radius: r * CGFloat.random(in: 0.2...0.6, using: &rng),
                       startAngle: start, endAngle: start + .random(in: 0.8...2.2, using: &rng), clockwise: false)
            ctx.strokePath()
        }
    }
}
