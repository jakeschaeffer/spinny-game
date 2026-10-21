import SwiftUI

struct GameOverView: View {
    let model: GameModel
    /// Ignore taps for a moment so a finger still down from the crash doesn't skip the results.
    @State private var ready = false

    var body: some View {
        ZStack {
            if let trace = model.lastTrace {
                // Keep the top clear so the line shows through, and darken behind the card.
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    TraceShareArea(model: model, trace: trace, ready: ready)
                    card
                }
            } else {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                card
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            ready = true
        }
    }

    private var card: some View {
        SpaceCard {
            ZStack(alignment: .topTrailing) {
                results
                GlassIconButton(systemName: "trophy.fill", label: "Leaderboard") { model.showLeaderboard() }
                    .offset(x: 14, y: -14)
            }
        }
    }

    private var results: some View {
        let run = model.lastRun
        return VStack(spacing: 22) {
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
                    Text("\(model.runDifficulty.badge) BEST \(model.best)")
                        .font(.display(13, .bold))
                        .tracking(1.5)
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            HStack(spacing: 0) {
                stat("BEST COMBO", run.map { "×\(max($0.bestCombo, 1))" } ?? "–") {
                    if run?.isNewBestCombo == true {
                        Label("NEW BEST", systemImage: "star.fill")
                            .foregroundStyle(Color.spaceGold)
                    } else if model.bestCombo > 1 {
                        Text("\(model.runDifficulty.badge) BEST ×\(model.bestCombo)")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
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

    private func stat(_ title: String, _ value: String,
                      @ViewBuilder note: () -> some View = { EmptyView() }) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.display(20, .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(title)
                .font(.display(10, .semibold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
            note()
                .font(.display(9, .heavy))
                .tracking(1)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

/// The space above the results card, where the camera frames the finished run's whole line. Tapping it
/// shares a picture of the line.
private struct TraceShareArea: View {
    let model: GameModel
    let trace: Trace
    let ready: Bool
    @State private var poster: UIImage?

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            Group {
                if let poster {
                    ShareLink(item: Image(uiImage: poster), subject: Text("Yet Another Line"),
                              message: Text("I climbed \(score) in Yet Another Line."),
                              preview: SharePreview("My line", image: Image(uiImage: poster))) {
                        hint
                    }
                    .disabled(!ready)
                } else {
                    hint
                }
            }
            .task(id: frame) {
                // Let the card's entrance settle so the camera only moves once.
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                model.frameTrace(in: CGRect(x: frame.minX + 24, y: frame.minY + 8,
                                            width: frame.width - 48, height: frame.height - 40))
            }
        }
        .task {
            poster = TracePoster.render(trace, score: score, mode: model.runDifficulty.badge,
                                        bestCombo: model.lastRun?.bestCombo ?? 0)
        }
    }

    private var score: Int { model.lastRun?.score ?? 0 }

    private var hint: some View {
        VStack {
            Spacer()
            Label("TAP YOUR LINE TO SHARE", systemImage: "square.and.arrow.up")
                .font(.display(10, .heavy))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}
