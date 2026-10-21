import SwiftUI

/// The end of a lesson run: what went wrong and a retry, or the all-clear to play for real.
struct LessonOverView: View {
    let model: GameModel
    /// Ignore taps for a moment so a finger still down from the crash doesn't skip the explanation.
    @State private var ready = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            SpaceCard {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        Image(systemName: content.icon)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(content.accent)
                        Text(content.title)
                            .font(.display(24, .black))
                            .tracking(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                        Text(content.message)
                            .font(.system(size: 15, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 12) {
                        if model.lessonOutcome == .passed {
                            PrimaryButton(title: "PLAY \(model.difficulty.badge)", systemImage: "sparkles") { model.play() }
                        } else {
                            PrimaryButton(title: "TRY AGAIN", systemImage: "arrow.clockwise") { model.retryLesson() }
                        }
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
                    "Latch onto a planet before you drop off the bottom of the screen. Hold as soon as one lights up.")
        }
    }
}
