// The iPhone's version of this screen; Apple TV's are in YetAnotherLineTV/.
#if os(iOS)
import SwiftUI

@main
struct YetAnotherLineApp: App {
    // Owned here rather than in ContentView so it's created exactly once.
    @State private var model = GameModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
#endif
