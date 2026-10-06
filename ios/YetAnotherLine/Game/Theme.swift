import SwiftUI
import UIKit

struct PlanetPalette {
    let main: UIColor
    let light: UIColor
    let dark: UIColor

    init(_ main: UInt32, _ light: UInt32, _ dark: UInt32) {
        self.main = UIColor(hex: main)
        self.light = UIColor(hex: light)
        self.dark = UIColor(hex: dark)
    }
}

enum Theme {
    static let spaceBottom = UIColor(hex: 0x03040B)
    static let cyan = UIColor(hex: 0x67E8F9)
    static let violet = UIColor(hex: 0xA78BFA)
    static let magenta = UIColor(hex: 0xF472B6)
    static let gold = UIColor(hex: 0xFDE68A)
    static let danger = UIColor(hex: 0xFB7185)

    static let nebulaTints: [UIColor] = ([0x7C3AED, 0xDB2777, 0x0D9488, 0x2563EB] as [UInt32]).map { UIColor(hex: $0) }
    static let starTints: [UIColor] = ([0xFFFFFF, 0xFFFFFF, 0xC7D2FE, 0xFDE68A, 0xA5F3FC] as [UInt32]).map { UIColor(hex: $0) }

    /// The original web game's eight node colours, reused as planet palettes.
    static let planetPalettes: [PlanetPalette] = [
        PlanetPalette(0x4ADE80, 0x86EFAC, 0x166534),
        PlanetPalette(0x38BDF8, 0x7DD3FC, 0x075985),
        PlanetPalette(0x818CF8, 0xA5B4FC, 0x3730A3),
        PlanetPalette(0xFB7185, 0xFDA4AF, 0x9F1239),
        PlanetPalette(0xFACC15, 0xFDE047, 0xA16207),
        PlanetPalette(0xF97316, 0xFDBA74, 0x9A3412),
        PlanetPalette(0xC084FC, 0xD8B4FE, 0x6B21A8),
        PlanetPalette(0x34D399, 0x6EE7B7, 0x065F46),
    ]

    /// Trail colour from its tail (0) to the comet's head (1).
    static func trailColor(at fraction: CGFloat) -> UIColor {
        fraction < 0.5
            ? magenta.mixed(with: violet, fraction * 2)
            : violet.mixed(with: cyan, (fraction - 0.5) * 2)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    func mixed(with other: UIColor, _ amount: CGFloat) -> UIColor {
        let t = min(max(amount, 0), 1)
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}

extension Color {
    static let spaceCyan = Color(uiColor: Theme.cyan)
    static let spaceViolet = Color(uiColor: Theme.violet)
    static let spaceMagenta = Color(uiColor: Theme.magenta)
    static let spaceGold = Color(uiColor: Theme.gold)
    static let spaceInk = Color(uiColor: UIColor(hex: 0x0A0B1E))
}
