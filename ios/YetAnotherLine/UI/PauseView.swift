import SwiftUI

struct PauseView: View {
    let model: GameModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            SpaceCard {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("PAUSED")
                            .font(.display(30, .black))
                            .tracking(4)
                            .foregroundStyle(.white)
                        Text("ALTITUDE \(model.score)")
                            .font(.display(12, .bold))
                            .tracking(2)
                            .monospacedDigit()
                            .foregroundStyle(Color.spaceCyan.opacity(0.85))
                    }
                    VStack(spacing: 12) {
                        PrimaryButton(title: "RESUME", systemImage: "play.fill") { model.resume() }
                        SecondaryButton(title: "RESTART", systemImage: "arrow.clockwise") { model.play() }
                        SecondaryButton(title: "SETTINGS", systemImage: "slider.horizontal.3") { model.showSettings = true }
                        SecondaryButton(title: "MENU") { model.goToMenu() }
                    }
                }
            }
        }
    }
}
