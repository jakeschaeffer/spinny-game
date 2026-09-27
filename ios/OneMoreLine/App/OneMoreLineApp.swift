import SwiftUI

@main
struct OneMoreLineApp: App {
    // Owned here rather than in ContentView so it's created exactly once.
    @State private var model = GameModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
