import SwiftUI

struct HUDView: View {
    let model: GameModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(model.score)")
                        .font(.display(52, .black))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .spaceCyan.opacity(0.5), radius: 12)
                    bestLine
                }
                .allowsHitTesting(false)
                Spacer()
                GlassIconButton(systemName: "pause.fill", label: "Pause") { model.pause() }
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)

            HStack {
                if model.combo > 1 {
                    ComboBadge(combo: model.combo)
                        .id(model.combo)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                Spacer()
            }
            .frame(height: 34)
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .allowsHitTesting(false)
            // Scoped to the badge so the constantly changing score never cross-fades.
            .animation(.spring(duration: 0.3, bounce: 0.4), value: model.combo)

            Spacer()
            // Low on the screen, behind the comet, so it never hides the planets ahead.
            ZStack {
                if model.showTutorial {
                    TutorialCard()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.4), value: model.showTutorial)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder private var bestLine: some View {
        if model.passedBest {
            Label("NEW BEST", systemImage: "star.fill")
                .font(.display(12, .heavy))
                .tracking(1.5)
                .foregroundStyle(Color.spaceGold)
        } else if model.best > 0 {
            Text("BEST \(model.best)")
                .font(.display(12, .bold))
                .tracking(1.5)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

private struct ComboBadge: View {
    let combo: Int

    var body: some View {
        Text("×\(combo) COMBO")
            .font(.display(13, .black))
            .tracking(1.5)
            .foregroundStyle(Color(white: 0.08))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(LinearGradient(colors: [.spaceGold, Color(uiColor: UIColor(hex: 0xFB923C))],
                                       startPoint: .leading, endPoint: .trailing), in: Capsule())
            .shadow(color: .spaceGold.opacity(0.5), radius: 10)
    }
}

private struct TutorialCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            row(icon: "hand.tap.fill", action: "HOLD", detail: "to orbit a planet")
            row(icon: "arrow.up.forward", action: "RELEASE", detail: "to launch")
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))
    }

    private func row(icon: String, action: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.spaceCyan)
                .frame(width: 26)
            Text(action)
                .font(.display(17, .black))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
