import SpriteKit
import SwiftUI

struct TVContentView: View {
    @Bindable var model: GameModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SpriteView(scene: model.scene, preferredFramesPerSecond: 120)
                .ignoresSafeArea()

            if model.phase == .playing || model.phase == .paused {
                TVHUDView(model: model)
                    .transition(.opacity)
            }
            if model.phase == .paused {
                TVPauseView(model: model)
                    .transition(.opacity)
            }
            if model.phase == .menu {
                TVMenuView(model: model)
                    .transition(.opacity)
            }
            if model.phase == .gameOver {
                TVGameOverView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            if model.phase == .lessonOver {
                TVLessonOverView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .background(Color.black)
        .animation(.easeInOut(duration: 0.3), value: model.phase)
        .fullScreenCover(isPresented: $model.showSettings) {
            TVSettingsView(model: model)
        }
        .alert("Sign in to Game Center", isPresented: $model.showGameCenterSignIn) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Open Settings › Users and Accounts, choose your user, and sign in to Game Center to see the leaderboards and post your scores.")
        }
        .task {
            #if DEBUG
            // Game Center's sign-in screen would cover the game in UI tests and screenshots.
            if ProcessInfo.processInfo.arguments.contains("-noGameCenter") { return }
            #endif
            model.gameCenter.authenticate()
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.pause() }
        }
        #if DEBUG
        .task { await showDebugScreen() }
        #endif
    }

    #if DEBUG
    /// `-screen pause|settings|lesson` opens that screen at launch, to check it without a remote.
    private func showDebugScreen() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screen"), arguments.indices.contains(index + 1) else { return }
        try? await Task.sleep(for: .seconds(1))
        switch arguments[index + 1] {
        case "pause":
            model.play()
            try? await Task.sleep(for: .seconds(4))
            model.pause()
        case "settings":
            model.showSettings = true
        case "lesson":
            model.startLesson()
        case "play":
            model.play()
        default:
            break
        }
    }
    #endif
}
