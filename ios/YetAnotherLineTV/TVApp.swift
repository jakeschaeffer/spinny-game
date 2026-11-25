import SwiftUI
import UIKit

// Apple TV starts from UIKit rather than a SwiftUI `App` so the window can be a `RemoteWindow`, which
// sees every touch and press from the remote before the focus engine does.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let model = GameModel()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = RemoteWindow(windowScene: scene)
        window.model = model
        window.rootViewController = UIHostingController(rootView: TVContentView(model: model))
        window.makeKeyAndVisible()
        self.window = window
    }
}
