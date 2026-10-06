import SwiftUI

extension Font {
    /// Wide, heavy system type for the game's sci-fi display text.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight).width(.expanded)
    }
}

extension ShapeStyle where Self == LinearGradient {
    static var nebula: LinearGradient {
        LinearGradient(colors: [.spaceCyan, .spaceViolet, .spaceMagenta], startPoint: .leading, endPoint: .trailing)
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.display(18, .black))
            .tracking(2)
            .foregroundStyle(.white)
            .padding(.horizontal, 40)
            .frame(minWidth: 220, minHeight: 60)
            .background(Capsule().fill(.nebula))
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: .spaceCyan.opacity(0.4), radius: 20)
            .shadow(color: .spaceMagenta.opacity(0.3), radius: 28, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.display(14, .bold))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.9))
            .frame(minWidth: 220, minHeight: 50)
            .background(Capsule().fill(.white.opacity(0.07)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct GlassIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .glassCircle()
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
    }
}

/// A dark translucent panel for the pause and game-over cards.
struct SpaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(28)
            .frame(maxWidth: 360)
            .background {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Color.spaceInk.opacity(0.55)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .environment(\.colorScheme, .dark)
            .padding(24)
    }
}

extension View {
    /// Liquid Glass where available, frosted material otherwise.
    @ViewBuilder func glassCircle() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: Circle())
        } else {
            background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        }
    }
}
