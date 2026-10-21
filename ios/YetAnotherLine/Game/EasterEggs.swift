import SpriteKit
import UIKit

/// Decorative sights at set heights, once per run. They pass behind the planets and never collide.
enum EasterEgg: Int, CaseIterable {
    case satellite, ufo, astronaut, rocket, meteorShower

    var score: Int {
        switch self {
        case .satellite: 250
        case .ufo: 500
        case .astronaut: 1000
        case .rocket: 1500
        case .meteorShower: 2000
        }
    }

    /// The eggs to show at `score`, leaving out the ones already shown this run.
    static func due(at score: Int, shown: Set<EasterEgg>) -> [EasterEgg] {
        allCases.filter { score >= $0.score && !shown.contains($0) }
    }

    /// A self-running node, in screen-pinned world units centred on the view, that removes itself when done.
    func makeNode(visible: CGSize) -> SKNode {
        switch self {
        case .satellite: EggNodes.satellite(visible)
        case .ufo: EggNodes.ufo(visible)
        case .astronaut: EggNodes.astronaut(visible)
        case .rocket: EggNodes.rocket(visible)
        case .meteorShower: EggNodes.meteorShower(visible)
        }
    }
}

private enum EggNodes {
    static func satellite(_ visible: CGSize) -> SKNode {
        let node = SKNode()
        let body = SKSpriteNode(texture: EggTextures.shared.satellite, size: CGSize(width: 70, height: 28))
        body.run(.repeatForever(.rotate(byAngle: 0.6, duration: 7)))
        node.addChild(body)
        let light = glow(Theme.danger, size: 9)
        light.position = CGPoint(x: 0, y: 13)
        light.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0.1), .wait(forDuration: 0.25),
                                            .fadeAlpha(to: 0.1, duration: 0.2), .wait(forDuration: 0.6)])))
        body.addChild(light)

        let edge = visible.width / 2 + 60
        node.position = CGPoint(x: -edge, y: visible.height * 0.24)
        node.run(.sequence([
            .group([.moveTo(x: edge, duration: 10), .moveBy(x: 0, y: -visible.height * 0.25, duration: 10)]),
            .removeFromParent(),
        ]))
        return node
    }

    static func ufo(_ visible: CGSize) -> SKNode {
        let node = SKNode()
        let beam = SKShapeNode(path: {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -9, y: -6))
            path.addLine(to: CGPoint(x: 9, y: -6))
            path.addLine(to: CGPoint(x: 30, y: -90))
            path.addLine(to: CGPoint(x: -30, y: -90))
            path.closeSubpath()
            return path
        }())
        beam.fillColor = Theme.cyan.withAlphaComponent(0.16)
        beam.strokeColor = .clear
        beam.blendMode = .add
        beam.alpha = 0
        node.addChild(beam)

        let saucer = SKSpriteNode(texture: EggTextures.shared.ufo, size: CGSize(width: 64, height: 30))
        node.addChild(saucer)
        let colors = [Theme.gold, Theme.magenta, Theme.cyan, Theme.gold, Theme.magenta]
        for (index, color) in colors.enumerated() {
            let light = glow(color, size: 8)
            light.position = CGPoint(x: CGFloat(index - 2) * 11, y: -6)
            light.alpha = 0.3
            light.run(.sequence([.wait(forDuration: Double(index) * 0.12), .repeatForever(.sequence([
                .fadeAlpha(to: 1, duration: 0.1), .wait(forDuration: 0.15), .fadeAlpha(to: 0.3, duration: 0.25), .wait(forDuration: 0.1),
            ]))]))
            saucer.addChild(light)
        }
        saucer.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 0.4), .moveBy(x: 0, y: -3, duration: 0.4)])))

        let edge = visible.width / 2 + 50
        node.position = CGPoint(x: edge, y: visible.height * 0.3)
        let arrive = SKAction.group([.moveTo(x: 70, duration: 0.9), .sequence([.rotate(toAngle: 0.25, duration: 0.2),
                                                                                  .rotate(toAngle: 0, duration: 0.7)])])
        arrive.timingMode = .easeOut
        let leave = SKAction.group([.moveTo(x: -edge - 40, duration: 0.6), .moveBy(x: 0, y: 40, duration: 0.6),
                                    .rotate(toAngle: -0.3, duration: 0.3)])
        leave.timingMode = .easeIn
        node.run(.sequence([
            arrive,
            .run { beam.run(.sequence([.fadeIn(withDuration: 0.15), .repeat(.sequence([
                .fadeAlpha(to: 0.6, duration: 0.08), .fadeAlpha(to: 1, duration: 0.08),
            ]), count: 6), .fadeOut(withDuration: 0.2)])) },
            .wait(forDuration: 1.4),
            leave,
            .removeFromParent(),
        ]))
        return node
    }

    static func astronaut(_ visible: CGSize) -> SKNode {
        let node = SKNode()
        let body = SKSpriteNode(texture: EggTextures.shared.astronaut, size: CGSize(width: 36, height: 46))
        let arm = SKSpriteNode(texture: EggTextures.shared.astronautArm, size: CGSize(width: 7, height: 17))
        arm.anchorPoint = CGPoint(x: 0.5, y: 0.05)
        arm.position = CGPoint(x: 8, y: 6)
        arm.zRotation = -0.5
        arm.zPosition = 1
        arm.run(.repeatForever(.sequence([.rotate(toAngle: -1.0, duration: 0.3), .rotate(toAngle: -0.2, duration: 0.3)])))
        body.addChild(arm)
        node.addChild(body)
        body.run(.repeatForever(.sequence([.rotate(byAngle: 0.25, duration: 2.5), .rotate(byAngle: -0.25, duration: 2.5)])))

        let edge = visible.width / 2 + 40
        node.position = CGPoint(x: -edge, y: visible.height * 0.18)
        node.run(.sequence([
            .group([.moveTo(x: edge, duration: 12),
                    .sequence([.moveBy(x: 0, y: 30, duration: 6), .moveBy(x: 0, y: -50, duration: 6)])]),
            .removeFromParent(),
        ]))
        return node
    }

    static func rocket(_ visible: CGSize) -> SKNode {
        let node = SKNode()
        let flame = SKEmitterNode()
        flame.particleTexture = Textures.shared.softGlow
        flame.particleBirthRate = 220
        flame.particleLifetime = 0.5
        flame.particleLifetimeRange = 0.2
        flame.emissionAngle = -.pi / 2
        flame.emissionAngleRange = 0.35
        flame.particleSpeed = 120
        flame.particleSpeedRange = 40
        flame.particleScale = 0.12
        flame.particleScaleSpeed = 0.1
        flame.particleAlphaSpeed = -1.8
        flame.particleColorBlendFactor = 1
        flame.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [UIColor.white, Theme.gold, UIColor(hex: 0xFB923C), Theme.magenta.withAlphaComponent(0)],
            times: [0, 0.15, 0.45, 1])
        flame.particleBlendMode = .add
        flame.position = CGPoint(x: 0, y: -28)
        node.addChild(flame)
        node.addChild(SKSpriteNode(texture: EggTextures.shared.rocket, size: CGSize(width: 22, height: 60)))

        node.position = CGPoint(x: 120, y: -visible.height / 2 - 60)
        let climb = SKAction.moveTo(y: visible.height / 2 + 80, duration: 2.6)
        climb.timingMode = .easeIn
        node.run(.sequence([
            .group([climb, .sequence([.rotate(toAngle: 0.06, duration: 0.6), .rotate(toAngle: -0.04, duration: 1),
                                      .rotate(toAngle: 0.02, duration: 1)])]),
            .removeFromParent(),
        ]))
        return node
    }

    static func meteorShower(_ visible: CGSize) -> SKNode {
        let node = SKNode()
        // Down and to the left, as if raining past from the upper right.
        let angle = -.pi * 0.78
        let direction = CGVector(dx: cos(angle), dy: sin(angle))
        let spawn = SKAction.run {
            let meteor = SKSpriteNode(texture: EggTextures.shared.meteor, size: CGSize(width: .random(in: 70...120), height: 6))
            meteor.anchorPoint = CGPoint(x: 1, y: 0.5)
            meteor.zRotation = angle
            meteor.blendMode = .add
            meteor.color = Theme.starTints.randomElement() ?? .white
            meteor.colorBlendFactor = 0.4
            meteor.addChild(glow(meteor.color, size: 16))
            meteor.position = CGPoint(x: .random(in: -visible.width / 2...visible.width * 0.7),
                                      y: visible.height / 2 + .random(in: 0...80))
            let distance = CGFloat.random(in: 380...560)
            let fall = SKAction.moveBy(x: direction.dx * distance, y: direction.dy * distance, duration: .random(in: 0.7...1.1))
            meteor.run(.sequence([.group([fall, .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.5)])]),
                                  .removeFromParent()]))
            node.addChild(meteor)
        }
        node.run(.sequence([
            .repeat(.sequence([spawn, .wait(forDuration: 0.14, withRange: 0.16)]), count: 26),
            .wait(forDuration: 1.5),
            .removeFromParent(),
        ]))
        return node
    }

    private static func glow(_ color: UIColor, size: CGFloat) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: Textures.shared.softGlow, size: CGSize(width: size, height: size))
        sprite.color = color
        sprite.colorBlendFactor = 1
        sprite.blendMode = .add
        return sprite
    }
}

/// Drawn on first use, at 3x so they stay crisp on any screen.
private final class EggTextures {
    static let shared = EggTextures()

    lazy var satellite = render(CGSize(width: 70, height: 28)) { ctx in
        // Solar panels with a cell grid, struts, then the foil-wrapped body and its antenna.
        for x in [CGFloat(2), 44] {
            let panel = CGRect(x: x, y: 8, width: 24, height: 12)
            ctx.setFillColor(UIColor(hex: 0x1E3A8A).cgColor)
            ctx.fill(panel)
            ctx.setStrokeColor(UIColor(hex: 0x60A5FA).cgColor)
            ctx.setLineWidth(0.6)
            for column in 1..<4 { ctx.strokeLineSegments(between: [CGPoint(x: x + CGFloat(column) * 6, y: 8), CGPoint(x: x + CGFloat(column) * 6, y: 20)]) }
            ctx.strokeLineSegments(between: [CGPoint(x: x, y: 14), CGPoint(x: x + 24, y: 14)])
            ctx.stroke(panel)
        }
        ctx.setStrokeColor(UIColor(hex: 0x9CA3AF).cgColor)
        ctx.setLineWidth(1.2)
        ctx.strokeLineSegments(between: [CGPoint(x: 26, y: 14), CGPoint(x: 44, y: 14), CGPoint(x: 35, y: 7), CGPoint(x: 35, y: 1)])
        ctx.setFillColor(UIColor(hex: 0xD4A84B).cgColor)
        let body = UIBezierPath(roundedRect: CGRect(x: 28, y: 7, width: 14, height: 14), cornerRadius: 2)
        body.fill()
        ctx.setStrokeColor(UIColor(hex: 0x8A6A22).cgColor)
        ctx.setLineWidth(0.6)
        for y in [CGFloat(11), 15, 19] { ctx.strokeLineSegments(between: [CGPoint(x: 29, y: y), CGPoint(x: 41, y: y - 2)]) }
    }

    lazy var ufo = render(CGSize(width: 64, height: 30)) { ctx in
        // Glass dome with a little green pilot, over a silver saucer.
        UIColor(hex: 0x67E8F9, alpha: 0.35).setFill()
        UIBezierPath(ovalIn: CGRect(x: 20, y: 1, width: 24, height: 20)).fill()
        UIColor(hex: 0x4ADE80).setFill()
        UIBezierPath(ovalIn: CGRect(x: 27, y: 6, width: 10, height: 10)).fill()
        UIColor.black.setFill()
        UIBezierPath(ovalIn: CGRect(x: 29, y: 9, width: 2.5, height: 3)).fill()
        UIBezierPath(ovalIn: CGRect(x: 32.5, y: 9, width: 2.5, height: 3)).fill()
        UIColor(white: 1, alpha: 0.55).setFill()
        UIBezierPath(ovalIn: CGRect(x: 24, y: 4, width: 6, height: 4)).fill()

        let saucer = UIBezierPath(ovalIn: CGRect(x: 2, y: 13, width: 60, height: 14))
        ctx.saveGState()
        saucer.addClip()
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor(hex: 0xF3F4F6).cgColor, UIColor(hex: 0x6B7280).cgColor] as CFArray,
                                  locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 13), end: CGPoint(x: 0, y: 27), options: [])
        ctx.restoreGState()
        UIColor(hex: 0x374151).setStroke()
        saucer.lineWidth = 0.8
        saucer.stroke()
    }

    lazy var astronaut = render(CGSize(width: 36, height: 46)) { _ in
        let suit = UIColor(hex: 0xF3F4F6)
        UIColor(hex: 0x9CA3AF).setFill()
        UIBezierPath(roundedRect: CGRect(x: 6, y: 16, width: 24, height: 19), cornerRadius: 4).fill()
        suit.setFill()
        UIBezierPath(roundedRect: CGRect(x: 11, y: 31, width: 6, height: 13), cornerRadius: 3).fill()
        UIBezierPath(roundedRect: CGRect(x: 19, y: 31, width: 6, height: 13), cornerRadius: 3).fill()
        UIBezierPath(roundedRect: CGRect(x: 9, y: 16, width: 18, height: 19), cornerRadius: 5).fill()
        UIBezierPath(roundedRect: CGRect(x: 4, y: 18, width: 6, height: 14), cornerRadius: 3).fill()
        UIColor(hex: 0x6B7280).setFill()
        UIBezierPath(roundedRect: CGRect(x: 10, y: 41, width: 8, height: 4), cornerRadius: 1.5).fill()
        UIBezierPath(roundedRect: CGRect(x: 18, y: 41, width: 8, height: 4), cornerRadius: 1.5).fill()
        for (index, hex) in [0xEF4444, 0x38BDF8, 0xFACC15].enumerated() {
            UIColor(hex: UInt32(hex)).setFill()
            UIBezierPath(ovalIn: CGRect(x: 13 + CGFloat(index) * 3.5, y: 22, width: 2.4, height: 2.4)).fill()
        }
        suit.setFill()
        UIBezierPath(ovalIn: CGRect(x: 8, y: 1, width: 20, height: 20)).fill()
        UIColor(hex: 0xD97706).setFill()
        UIBezierPath(ovalIn: CGRect(x: 11.5, y: 5, width: 14, height: 11)).fill()
        UIColor(hex: 0xFDE68A, alpha: 0.8).setFill()
        UIBezierPath(ovalIn: CGRect(x: 14, y: 6.5, width: 5, height: 3)).fill()
    }

    lazy var astronautArm = render(CGSize(width: 7, height: 17)) { _ in
        UIColor(hex: 0xF3F4F6).setFill()
        UIBezierPath(roundedRect: CGRect(x: 0.5, y: 3, width: 6, height: 14), cornerRadius: 3).fill()
        UIColor(hex: 0x6B7280).setFill()
        UIBezierPath(ovalIn: CGRect(x: 0.5, y: 0, width: 6, height: 6)).fill()
    }

    lazy var rocket = render(CGSize(width: 22, height: 60)) { ctx in
        let red = UIColor(hex: 0xEF4444)
        red.setFill()
        for side: CGFloat in [-1, 1] {
            let fin = UIBezierPath()
            fin.move(to: CGPoint(x: 11 + side * 6, y: 36))
            fin.addLine(to: CGPoint(x: 11 + side * 11, y: 54))
            fin.addLine(to: CGPoint(x: 11 + side * 6, y: 50))
            fin.close()
            fin.fill()
        }
        let body = UIBezierPath()
        body.move(to: CGPoint(x: 11, y: 0))
        body.addCurve(to: CGPoint(x: 17, y: 18), controlPoint1: CGPoint(x: 15, y: 4), controlPoint2: CGPoint(x: 17, y: 10))
        body.addLine(to: CGPoint(x: 17, y: 50))
        body.addLine(to: CGPoint(x: 5, y: 50))
        body.addLine(to: CGPoint(x: 5, y: 18))
        body.addCurve(to: CGPoint(x: 11, y: 0), controlPoint1: CGPoint(x: 5, y: 10), controlPoint2: CGPoint(x: 7, y: 4))
        UIColor(hex: 0xF8FAFC).setFill()
        body.fill()
        ctx.saveGState()
        body.addClip()
        red.setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 22, height: 12))
        UIColor(white: 0, alpha: 0.12).setFill()
        ctx.fill(CGRect(x: 13, y: 0, width: 4, height: 50))
        ctx.restoreGState()
        UIColor(hex: 0x38BDF8).setFill()
        UIBezierPath(ovalIn: CGRect(x: 7.5, y: 21, width: 7, height: 7)).fill()
        UIColor.white.setStroke()
        let window = UIBezierPath(ovalIn: CGRect(x: 7.5, y: 21, width: 7, height: 7))
        window.lineWidth = 1
        window.stroke()
        UIColor(hex: 0x6B7280).setFill()
        ctx.fill(CGRect(x: 7, y: 50, width: 8, height: 5))
    }

    lazy var meteor = render(CGSize(width: 90, height: 6)) { ctx in
        let white = { (alpha: CGFloat) in UIColor(white: 1, alpha: alpha).cgColor }
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [white(0), white(0.5), white(1)] as CFArray, locations: [0, 0.8, 1])!
        UIBezierPath(roundedRect: CGRect(x: 0, y: 1.5, width: 90, height: 3), cornerRadius: 1.5).addClip()
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 90, y: 0), options: [])
    }

    private func render(_ size: CGSize, draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let texture = SKTexture(image: UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext) })
        texture.filteringMode = .linear
        return texture
    }
}
