import SwiftUI

/// Sizes for a 1920 × 1080 point screen seen from the sofa.
enum TVLayout {
    /// Keeps content clear of the edge of the TV.
    static let overscan: CGFloat = 80
    /// Gap between the playfield's walls and anything beside them.
    static let wallGap: CGFloat = 48
}

/// Puts content in the gutters either side of the playfield, which runs down the middle of the screen.
struct Gutters<Left: View, Right: View>: View {
    @ViewBuilder let left: Left
    @ViewBuilder let right: Right

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                left
                    .padding(.leading, TVLayout.overscan)
                    .padding(.trailing, TVLayout.wallGap)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Color.clear
                    .frame(width: GameScene.playfieldWidth(in: proxy.size))
                right
                    .padding(.leading, TVLayout.wallGap)
                    .padding(.trailing, TVLayout.overscan)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.vertical, 60)
        }
        .ignoresSafeArea()
    }
}

/// A capsule button that lights up with the nebula gradient when the remote focuses it.
struct TVButton: View {
    let title: String
    var systemImage: String?
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
            }
        }
        .buttonStyle(TVButtonStyle(prominent: prominent))
    }
}

struct TVButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, prominent: prominent)
    }

    private struct Face: View {
        let configuration: Configuration
        let prominent: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            configuration.label
                .font(.display(prominent ? 30 : 24, .black))
                .tracking(2.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white.opacity(isFocused ? 1 : 0.8))
                .padding(.horizontal, 36)
                .frame(maxWidth: .infinity, minHeight: prominent ? 92 : 76)
                .background {
                    if isFocused {
                        Capsule().fill(.nebula)
                    } else {
                        Capsule().fill(.white.opacity(prominent ? 0.14 : 0.08))
                    }
                }
                .overlay(Capsule().strokeBorder(.white.opacity(isFocused ? 0.5 : 0.22), lineWidth: 2))
                .shadow(color: .spaceCyan.opacity(isFocused ? 0.5 : 0), radius: 28)
                .shadow(color: .spaceMagenta.opacity(isFocused ? 0.35 : 0), radius: 36, y: 10)
                .scaleEffect(configuration.isPressed ? 1.02 : isFocused ? 1.07 : 1)
                .animation(.spring(duration: 0.25), value: isFocused)
                .animation(.spring(duration: 0.2), value: configuration.isPressed)
        }
    }
}

/// A dark translucent panel for the pause, results and lesson cards.
struct TVCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(52)
            .frame(width: 660)
            .background {
                RoundedRectangle(cornerRadius: 52, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 52, style: .continuous).fill(Color.spaceInk.opacity(0.6)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 52, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 2)
            }
            .environment(\.colorScheme, .dark)
    }
}

/// The two-line "how to play", worded for however the remote is set to latch.
struct RemoteHowTo {
    let touch: Bool

    var hold: (action: String, detail: String) {
        touch ? ("TOUCH", "the remote to orbit") : ("HOLD", "the click to orbit")
    }

    var release: (action: String, detail: String) {
        touch ? ("LIFT", "to launch") : ("RELEASE", "to launch")
    }
}
