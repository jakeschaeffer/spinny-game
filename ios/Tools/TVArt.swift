// Draws the Apple TV app icon (three parallax layers) and Top Shelf images into the tvOS asset catalog.
// Run from the ios folder after changing the art:
//
//     swift Tools/TVArt.swift
//
import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let catalog = URL(fileURLWithPath: "YetAnotherLineTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets")

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: stops.map(\.1) as CFArray, locations: stops.map(\.0))!
}

struct Random {
    var seed: UInt64
    mutating func next() -> CGFloat {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return CGFloat(seed >> 11) / CGFloat(1 << 53)
    }
}

/// Renders `draw` in a `size`-point canvas (y up) at `scale` pixels per point, and writes a PNG.
func write(_ path: String, size: CGSize, scale: CGFloat, opaque: Bool, draw: (CGContext, CGSize) -> Void) {
    let info = opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast
    let ctx = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8,
                        bytesPerRow: 0, space: space, bitmapInfo: info.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    draw(ctx, size)
    let url = catalog.appendingPathComponent(path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}

func json(_ path: String, _ object: Any) {
    let url = catalog.appendingPathComponent(path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try! data.write(to: url)
}

let info: [String: Any] = ["author": "xcode", "version": 1]

// MARK: The pieces

func glow(_ ctx: CGContext, _ center: CGPoint, _ radius: CGFloat, _ hex: UInt32, _ alpha: CGFloat) {
    ctx.drawRadialGradient(gradient([(0, rgb(hex, alpha)), (0.4, rgb(hex, alpha * 0.35)), (1, rgb(hex, 0))]),
                           startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

/// Deep space: the game's background gradient, nebula glows and stars.
func drawSky(_ ctx: CGContext, _ size: CGSize, stars: Int, seed: UInt64) {
    ctx.drawLinearGradient(gradient([(0, rgb(0x03040B)), (0.55, rgb(0x0A0A24)), (1, rgb(0x1A0C44))]),
                           start: CGPoint(x: size.width * 0.3, y: 0), end: CGPoint(x: size.width * 0.7, y: size.height),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    let reach = max(size.width, size.height)
    glow(ctx, CGPoint(x: size.width * 0.82, y: size.height * 0.9), reach * 0.42, 0xDB2777, 0.32)
    glow(ctx, CGPoint(x: size.width * 0.12, y: size.height * 0.2), reach * 0.4, 0x0D9488, 0.25)
    glow(ctx, CGPoint(x: size.width * 0.52, y: size.height * 0.55), reach * 0.36, 0x7C3AED, 0.22)
    var random = Random(seed: seed)
    for _ in 0..<stars {
        let point = CGPoint(x: random.next() * size.width, y: random.next() * size.height)
        let radius = 0.8 + random.next() * 2.2
        ctx.setFillColor(rgb(0xFFFFFF, 0.25 + random.next() * 0.65))
        ctx.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// The ringed gas giant from the iPhone icon.
func drawPlanet(_ ctx: CGContext, center: CGPoint, radius: CGFloat) {
    glow(ctx, center, radius * 2.4, 0x818CF8, 0.45)
    func ring(front: Bool) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: 0.32)
        ctx.clip(to: front ? CGRect(x: -radius * 4, y: -radius * 4, width: radius * 8, height: radius * 4)
                           : CGRect(x: -radius * 4, y: 0, width: radius * 8, height: radius * 4))
        for (scale, alpha) in [(1.45, 0.25), (1.56, 0.5), (1.68, 0.32), (1.82, 0.6), (1.95, 0.3)] as [(CGFloat, CGFloat)] {
            let rx = radius * scale, ry = rx * 0.3
            ctx.setStrokeColor(rgb(0xC7D2FE, alpha))
            ctx.setLineWidth(radius * 0.086)
            ctx.strokeEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        }
        ctx.restoreGState()
    }
    ring(front: false)
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    ctx.clip()
    let light = CGPoint(x: center.x - radius * 0.4, y: center.y + radius * 0.4)
    ctx.drawRadialGradient(gradient([(0, rgb(0xA5B4FC)), (0.5, rgb(0x818CF8)), (1, rgb(0x312E81))]), startCenter: light,
                           startRadius: 0, endCenter: center, endRadius: radius * 1.1, options: [.drawsAfterEndLocation])
    for band in 0..<7 {
        let y = center.y - radius + CGFloat(band) * radius * 0.3 + radius * 0.11
        ctx.setFillColor(rgb(band % 2 == 0 ? 0x3730A3 : 0xC7D2FE, 0.22))
        ctx.fill(CGRect(x: center.x - radius, y: y, width: radius * 2, height: radius * 0.12))
    }
    ctx.drawRadialGradient(gradient([(0, rgb(0, 0)), (0.5, rgb(0, 0.3)), (0.75, rgb(0, 0.75)), (1, rgb(0, 0.9))]),
                           startCenter: light, startRadius: 0, endCenter: light, endRadius: radius * 2.05, options: [])
    ctx.restoreGState()
    ring(front: true)
}

/// The line: an orbit around the planet that peels off along its tangent to the comet.
func drawLine(_ ctx: CGContext, planet: CGPoint, orbit: CGFloat, head: CGPoint, width: CGFloat) {
    let toHead = CGVector(dx: head.x - planet.x, dy: head.y - planet.y)
    let endAngle = atan2(toHead.dy, toHead.dx) - acos(orbit / hypot(toHead.dx, toHead.dy))
    let path = CGMutablePath()
    path.addArc(center: planet, radius: orbit, startAngle: .pi * 0.62, endAngle: endAngle + 2 * .pi, clockwise: false)
    path.addLine(to: head)
    let from = CGPoint(x: planet.x - orbit, y: planet.y)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    for (scale, alpha) in [(6.4, 0.08), (3.6, 0.14), (1.8, 0.35), (1, 1)] as [(CGFloat, CGFloat)] {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setLineWidth(width * scale)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        let headColor: UInt32 = alpha == 1 ? 0xE0FBFF : 0x67E8F9
        ctx.drawLinearGradient(gradient([(0, rgb(0xF472B6, alpha)), (0.5, rgb(0xA78BFA, alpha)), (1, rgb(headColor, alpha))]),
                               start: from, end: head, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }
    glow(ctx, head, width * 17, 0x67E8F9, 0.9)
    glow(ctx, head, width * 6.4, 0xFFFFFF, 1)
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillEllipse(in: CGRect(x: head.x - width * 2.4, y: head.y - width * 2.4, width: width * 4.8, height: width * 4.8))
}

func line(_ text: String, size: CGFloat, weight: NSFont.Weight, kern: CGFloat) -> CTLine {
    let font = NSFont.systemFont(ofSize: size, weight: weight, width: .expanded)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .kern: kern, .foregroundColor: NSColor.white]
    return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
}

func drawText(_ ctx: CGContext, _ text: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight, kern: CGFloat,
              color: CGColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight, width: .expanded), .kern: kern,
        .foregroundColor: NSColor(cgColor: color)!,
    ]
    ctx.textPosition = point
    CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes)), ctx)
}

/// Text filled with the title's cyan-to-magenta gradient.
func drawGradientText(_ ctx: CGContext, _ text: String, at point: CGPoint, size: CGFloat, kern: CGFloat) {
    let line = line(text, size: size, weight: .black, kern: kern)
    let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: size * 0.25, color: rgb(0xA78BFA, 0.7))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.textPosition = point
    ctx.setTextDrawingMode(.clip)
    CTLineDraw(line, ctx)
    ctx.drawLinearGradient(gradient([(0, rgb(0x67E8F9)), (0.5, rgb(0xA78BFA)), (1, rgb(0xF472B6))]),
                           start: CGPoint(x: point.x, y: point.y + size * 0.8),
                           end: CGPoint(x: point.x + width, y: point.y), options: [])
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

// MARK: App icon

/// One layer of the icon, drawn in a 1280 × 768 design space whatever the output size.
func iconLayer(_ name: String, in size: CGSize, _ ctx: CGContext) {
    ctx.scaleBy(x: size.width / 1280, y: size.height / 768)
    let design = CGSize(width: 1280, height: 768)
    let planet = CGPoint(x: 500, y: 345)
    switch name {
    case "Back": drawSky(ctx, design, stars: 90, seed: 42)
    case "Middle": drawPlanet(ctx, center: planet, radius: 132)
    default: drawLine(ctx, planet: planet, orbit: 228, head: CGPoint(x: 965, y: 610), width: 9)
    }
}

let layers = ["Front", "Middle", "Back"]
for (stack, sizes) in [("App Icon", [(CGSize(width: 400, height: 240), [1, 2])]),
                       ("App Icon - App Store", [(CGSize(width: 1280, height: 768), [1])])] as [(String, [(CGSize, [Int])])] {
    json("\(stack).imagestack/Contents.json", ["info": info, "layers": layers.map { ["filename": "\($0).imagestacklayer"] }])
    for layer in layers {
        let folder = "\(stack).imagestack/\(layer).imagestacklayer"
        json("\(folder)/Contents.json", ["info": info])
        var images: [[String: String]] = []
        for (size, scales) in sizes {
            for scale in scales {
                let file = scale == 1 ? "\(layer).png" : "\(layer)@\(scale)x.png"
                write("\(folder)/Content.imageset/\(file)", size: size, scale: CGFloat(scale), opaque: layer == "Back") { ctx, size in
                    iconLayer(layer, in: size, ctx)
                }
                images.append(["filename": file, "idiom": "tv", "scale": "\(scale)x"])
            }
        }
        json("\(folder)/Content.imageset/Contents.json", ["images": images, "info": info])
    }
}

// MARK: Top Shelf

func topShelf(_ ctx: CGContext, _ size: CGSize) {
    drawSky(ctx, size, stars: Int(size.width / 8), seed: 7)
    // The art sits on the right; the title is left of it, clear of the edges.
    let planet = CGPoint(x: size.width - 620, y: 300)
    drawPlanet(ctx, center: planet, radius: 120)
    drawLine(ctx, planet: planet, orbit: 205, head: CGPoint(x: size.width - 190, y: 590), width: 8)
    let x = size.width * 0.5 - 760
    drawText(ctx, "YET ANOTHER", at: CGPoint(x: x + 6, y: 470), size: 46, weight: .bold, kern: 14, color: rgb(0xFFFFFF, 0.78))
    drawGradientText(ctx, "LINE", at: CGPoint(x: x, y: 250), size: 230, kern: 8)
    drawText(ctx, "SWING THROUGH THE STARS", at: CGPoint(x: x + 6, y: 180), size: 26, weight: .semibold, kern: 8,
             color: rgb(0x67E8F9, 0.9))
}

for (name, width) in [("Top Shelf Image", 1920), ("Top Shelf Image Wide", 2320)] as [(String, CGFloat)] {
    var images: [[String: String]] = []
    for scale in [1, 2] {
        let file = scale == 1 ? "TopShelf.png" : "TopShelf@2x.png"
        write("\(name).imageset/\(file)", size: CGSize(width: width, height: 720), scale: CGFloat(scale), opaque: true, draw: topShelf)
        images.append(["filename": file, "idiom": "tv", "scale": "\(scale)x"])
    }
    json("\(name).imageset/Contents.json", ["images": images, "info": info])
}

json("Contents.json", [
    "assets": [
        ["filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"],
        ["filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"],
        ["filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"],
        ["filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"],
    ],
    "info": info,
])
json("../Contents.json", ["info": info])
print("Wrote \(catalog.path)")
