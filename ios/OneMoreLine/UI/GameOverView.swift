import SwiftUI

struct GameOverView: View {
    let model: GameModel
    /// Ignore taps for a moment so a finger still down from the crash doesn't skip the results.
    @State private var ready = false

    var body: some View {
        let run = model.lastRun
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            SpaceCard {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text("SIGNAL LOST")
                            .font(.display(14, .heavy))
                            .tracking(6)
                            .foregroundStyle(Color.spaceMagenta)
                        Text("\(run?.score ?? 0)")
                            .font(.display(84, .black))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(.white)
                            .shadow(color: .spaceViolet.opacity(0.7), radius: 20)
                        if run?.isNewBest == true {
                            Label("NEW BEST", systemImage: "star.fill")
                                .font(.display(13, .black))
                                .tracking(1.5)
                                .foregroundStyle(Color(white: 0.08))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.spaceGold, in: Capsule())
                                .shadow(color: .spaceGold.opacity(0.6), radius: 12)
                        } else {
                            Text("BEST \(model.best)")
                                .font(.display(13, .bold))
                                .tracking(1.5)
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }

                    HStack(spacing: 0) {
                        stat("BEST COMBO", run.map { "×\(max($0.bestCombo, 1))" } ?? "–")
                        Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 34)
                        stat("FLIGHT", run.map { String(format: "%.1fs", $0.duration) } ?? "–")
                    }
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(spacing: 12) {
                        PrimaryButton(title: "FLY AGAIN", systemImage: "arrow.clockwise") { model.play() }
                        SecondaryButton(title: "MENU") { model.goToMenu() }
                    }
                    .disabled(!ready)
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            ready = true
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.display(20, .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(title)
                .font(.display(10, .semibold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
