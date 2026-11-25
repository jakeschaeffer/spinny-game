import SwiftUI

struct TVPauseView: View {
    @Bindable var model: GameModel
    @FocusState private var focusOnResume: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            TVCard {
                VStack(spacing: 36) {
                    VStack(spacing: 10) {
                        Text("PAUSED")
                            .font(.display(54, .black))
                            .tracking(6)
                            .foregroundStyle(.white)
                        Text("ALTITUDE \(model.score)")
                            .font(.display(22, .bold))
                            .tracking(3)
                            .monospacedDigit()
                            .foregroundStyle(Color.spaceCyan.opacity(0.85))
                    }
                    VStack(spacing: 18) {
                        TVButton(title: "RESUME", systemImage: "play.fill", prominent: true) { model.resume() }
                            .focused($focusOnResume)
                        TVButton(title: "RESTART", systemImage: "arrow.clockwise") { model.restart() }
                        if model.lesson != nil {
                            // On the phone this switch sits in the lesson's HUD, where a remote can't reach it.
                            TVButton(title: model.lessonBumpers ? "BUMPERS ON" : "BUMPERS OFF",
                                     systemImage: model.lessonBumpers ? "shield.fill" : "shield.slash") {
                                model.lessonBumpers.toggle()
                            }
                        }
                        TVButton(title: "SETTINGS", systemImage: "slider.horizontal.3") { model.showSettings = true }
                        TVButton(title: "MENU") { model.goToMenu() }
                    }
                }
            }
        }
        .onExitCommand { model.resume() }
        .onPlayPauseCommand { model.resume() }
        // Nothing is focusable during a run, so focus has to be sent to the card when it appears.
        .onAppear { focusOnResume = true }
    }
}

struct TVGameOverView: View {
    let model: GameModel
    /// Ignore clicks for a moment so one still coming from the crash doesn't skip the results.
    @State private var ready = false
    @FocusState private var focusOnPrimary: Bool

    var body: some View {
        ZStack {
            if model.lastTrace != nil {
                // The finished run's line fills the left of the screen; the results sit on the right.
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .trailing)
                    .ignoresSafeArea()
                HStack(spacing: 0) {
                    TraceArea(model: model)
                    card
                        .padding(.trailing, TVLayout.overscan + 40)
                }
            } else {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                card
            }
        }
        .ignoresSafeArea()
        .onExitCommand { model.goToMenu() }
        .onAppear { focusOnPrimary = true }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            ready = true
        }
    }

    private var card: some View {
        let run = model.lastRun
        return TVCard {
            VStack(spacing: 34) {
                VStack(spacing: 10) {
                    Text("SIGNAL LOST")
                        .font(.display(24, .heavy))
                        .tracking(9)
                        .foregroundStyle(Color.spaceMagenta)
                    Text("\(run?.score ?? 0)")
                        .font(.display(140, .black))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white)
                        .shadow(color: .spaceViolet.opacity(0.7), radius: 30)
                    if run?.isNewBest == true {
                        Label("NEW BEST", systemImage: "star.fill")
                            .font(.display(22, .black))
                            .tracking(2.5)
                            .foregroundStyle(Color(white: 0.08))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.spaceGold, in: Capsule())
                            .shadow(color: .spaceGold.opacity(0.6), radius: 18)
                    } else {
                        Text("\(model.runDifficulty.badge) BEST \(model.best)")
                            .font(.display(22, .bold))
                            .tracking(2.5)
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
                    Rectangle().fill(.white.opacity(0.15)).frame(width: 2, height: 56)
                    stat("FLIGHT", run.map { String(format: "%.1fs", $0.duration) } ?? "–")
                }
                .padding(.vertical, 22)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 18) {
                    TVButton(title: "FLY AGAIN", systemImage: "arrow.clockwise", prominent: true) {
                        if ready { model.play() }
                    }
                    .focused($focusOnPrimary)
                    TVButton(title: "LEADERBOARD", systemImage: "trophy.fill") {
                        if ready { model.showLeaderboard() }
                    }
                    TVButton(title: "MENU") {
                        if ready { model.goToMenu() }
                    }
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String,
                      @ViewBuilder note: () -> some View = { EmptyView() }) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.display(34, .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(title)
                .font(.display(17, .semibold))
                .tracking(2.5)
                .foregroundStyle(.white.opacity(0.5))
            note()
                .font(.display(15, .heavy))
                .tracking(1.5)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

/// The space beside the results card, where the camera frames the finished run's whole line.
private struct TraceArea: View {
    let model: GameModel

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            Color.clear
                .task(id: frame) {
                    // Let the card's entrance settle so the camera only moves once.
                    try? await Task.sleep(for: .milliseconds(80))
                    guard !Task.isCancelled else { return }
                    model.frameTrace(in: frame.insetBy(dx: TVLayout.overscan, dy: 70))
                }
        }
    }
}

/// The end of a lesson run: what went wrong and a retry, or the all-clear to play for real.
struct TVLessonOverView: View {
    @Bindable var model: GameModel
    /// Ignore clicks for a moment so one still coming from the crash doesn't skip the explanation.
    @State private var ready = false
    @FocusState private var focusOnPrimary: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            TVCard {
                VStack(spacing: 36) {
                    VStack(spacing: 16) {
                        Image(systemName: content.icon)
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(content.accent)
                        Text(content.title)
                            .font(.display(40, .black))
                            .tracking(3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                        Text(content.message)
                            .font(.system(size: 26, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 18) {
                        if model.lessonOutcome == .passed {
                            TVButton(title: "PLAY \(model.difficulty.badge)", systemImage: "sparkles", prominent: true) {
                                if ready { model.play() }
                            }
                            .focused($focusOnPrimary)
                        } else {
                            TVButton(title: "TRY AGAIN", systemImage: "arrow.clockwise", prominent: true) {
                                if ready { model.retryLesson() }
                            }
                            .focused($focusOnPrimary)
                            if model.lessonOutcome == .crashed(.wall), !model.lessonBumpers {
                                TVButton(title: "TRY WITH BUMPERS", systemImage: "shield.fill") {
                                    guard ready else { return }
                                    model.lessonBumpers = true
                                    model.retryLesson()
                                }
                            }
                        }
                        TVButton(title: "MENU") {
                            if ready { model.goToMenu() }
                        }
                    }
                }
            }
        }
        .onExitCommand { model.goToMenu() }
        .onAppear { focusOnPrimary = true }
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            ready = true
        }
    }

    private var content: (icon: String, accent: Color, title: String, message: String) {
        let danger = Color(uiColor: Theme.danger)
        switch model.lessonOutcome {
        case .passed, nil:
            return ("checkmark.seal.fill", .spaceGold, "YOU'RE READY",
                    "You passed \(Lesson.goal). Latch, swing, launch, and keep climbing. Now try it for real.")
        case .crashed(.wall):
            return ("exclamationmark.triangle.fill", danger, "YOU HIT A WALL",
                    "Flying into a side wall ends a run. Swinging through one while you're latched is safe, so let go when you're heading up and away from it.")
        case .crashed(.planet):
            return ("circle.circle.fill", danger, "YOU HIT A PLANET",
                    "Only the planet you're latched onto is safe to touch. Let go before your swing or your flight runs into another one.")
        case .crashed(.fell):
            return ("arrow.down.to.line", danger, "YOU FELL",
                    "Latch onto a planet before you drop off the bottom of the screen. Latch as soon as one lights up.")
        }
    }
}
