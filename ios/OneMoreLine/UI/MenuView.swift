import SwiftUI

struct MenuView: View {
    let model: GameModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Dim the demo run playing underneath so the title reads clearly.
            LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.2), .black.opacity(0.8)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 40)
                title
                Spacer()
                VStack(spacing: 26) {
                    PrimaryButton(title: "LAUNCH", systemImage: "sparkles") { model.play() }
                    howToPlay
                    if model.best > 0 { bestBadge }
                }
                Spacer()
                HStack(spacing: 16) {
                    GlassIconButton(systemName: model.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                    label: model.soundEnabled ? "Mute" : "Unmute") {
                        model.soundEnabled.toggle()
                    }
                    GlassIconButton(systemName: "slider.horizontal.3", label: "Settings") {
                        model.showSettings = true
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
    }

    private var title: some View {
        VStack(spacing: 4) {
            Text("ONE MORE")
                .font(.display(20, .bold))
                .tracking(10)
                .foregroundStyle(.white.opacity(0.75))
            Text("LINE")
                .font(.display(100, .black))
                .tracking(4)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(LinearGradient(colors: [.spaceCyan, .spaceViolet, .spaceMagenta],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .spaceViolet.opacity(0.7), radius: 24)
            Text("SWING THROUGH THE STARS")
                .font(.display(11, .semibold))
                .tracking(4)
                .foregroundStyle(Color.spaceCyan.opacity(0.85))
                .padding(.top, 4)
        }
        .accessibilityElement(children: .combine)
    }

    private var howToPlay: some View {
        HStack(spacing: 18) {
            step("HOLD", "to orbit")
            Circle().fill(.white.opacity(0.3)).frame(width: 4, height: 4)
            step("RELEASE", "to launch")
        }
    }

    private func step(_ action: String, _ detail: String) -> some View {
        VStack(spacing: 3) {
            Text(action)
                .font(.display(13, .heavy))
                .tracking(2)
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var bestBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundStyle(Color.spaceGold)
            Text("BEST \(model.best)")
                .font(.display(14, .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}
