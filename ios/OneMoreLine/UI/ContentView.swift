import SpriteKit
import SwiftUI

struct ContentView: View {
    @Bindable var model: GameModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SpriteView(scene: model.scene, preferredFramesPerSecond: 120)
                .ignoresSafeArea()

            if model.phase == .playing || model.phase == .paused {
                HUDView(model: model)
                    .transition(.opacity)
            }
            if model.phase == .paused {
                PauseView(model: model)
                    .transition(.opacity)
            }
            if model.phase == .menu {
                MenuView(model: model)
                    .transition(.opacity)
            }
            if model.phase == .gameOver {
                GameOverView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .background(Color.black)
        .animation(.easeInOut(duration: 0.3), value: model.phase)
        .sheet(isPresented: $model.showSettings) {
            SettingsView(model: model)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.pause() }
        }
    }
}
