import SwiftUI

/// The title screen: the title on the left, the buttons on the right, and the demo run flying up the
/// playfield between them.
struct TVMenuView: View {
    @Bindable var model: GameModel
    @State private var appeared = false
    @FocusState private var focusOnLaunch: Bool

    var body: some View {
        Gutters {
            VStack(spacing: 44) {
                title
                howToPlay
                modeBadge
            }
        } right: {
            VStack(spacing: 20) {
                TVButton(title: "LAUNCH", systemImage: "sparkles", prominent: true) { model.play() }
                    .focused($focusOnLaunch)
                TVButton(title: "LEARN TO FLY", systemImage: "graduationcap.fill") { model.startLesson() }
                TVButton(title: "MODE: \(model.difficulty.badge)", systemImage: "dial.medium.fill") {
                    model.difficulty = model.difficulty == .easy ? .astro : .easy
                }
                TVButton(title: "LEADERBOARD", systemImage: "trophy.fill") { model.showLeaderboard() }
                TVButton(title: "SETTINGS", systemImage: "slider.horizontal.3") { model.showSettings = true }
            }
            .frame(maxWidth: 460)
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            focusOnLaunch = true
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
    }

    private var title: some View {
        VStack(spacing: 6) {
            Text("YET ANOTHER")
                .font(.display(34, .bold))
                .tracking(10)
                .foregroundStyle(.white.opacity(0.75))
            Text("LINE")
                .font(.display(150, .black))
                .tracking(6)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(LinearGradient(colors: [.spaceCyan, .spaceViolet, .spaceMagenta],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .spaceViolet.opacity(0.7), radius: 36)
            Text("SWING THROUGH THE STARS")
                .font(.display(19, .semibold))
                .tracking(6)
                .foregroundStyle(Color.spaceCyan.opacity(0.85))
                .padding(.top, 6)
        }
        .accessibilityElement(children: .combine)
    }

    private var howToPlay: some View {
        let howTo = RemoteHowTo(touch: model.touchToLatch)
        return HStack(spacing: 30) {
            step(howTo.hold.action, howTo.hold.detail)
            Circle().fill(.white.opacity(0.3)).frame(width: 7, height: 7)
            step(howTo.release.action, howTo.release.detail)
        }
    }

    private func step(_ action: String, _ detail: String) -> some View {
        VStack(spacing: 5) {
            Text(action)
                .font(.display(24, .heavy))
                .tracking(3)
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var modeBadge: some View {
        HStack(spacing: 18) {
            Text(model.difficulty.badge)
                .font(.display(24, .heavy))
                .tracking(3)
                .foregroundStyle(Color.spaceCyan)
            if model.best > 0 {
                Rectangle().fill(.white.opacity(0.2)).frame(width: 2, height: 28)
                Image(systemName: "star.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.spaceGold)
                Text("BEST \(model.best)")
                    .font(.display(25, .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            if model.bestCombo > 1 {
                Rectangle().fill(.white.opacity(0.2)).frame(width: 2, height: 28)
                Text("×\(model.bestCombo)")
                    .font(.display(25, .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color.spaceGold)
                    .accessibilityLabel("best combo \(model.bestCombo)")
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .background(.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 2))
    }
}
