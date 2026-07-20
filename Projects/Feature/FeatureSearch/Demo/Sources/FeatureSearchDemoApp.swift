import UIKit

import FeatureSearch
import FeatureSearchInterface
#if DEV
import FeatureSearchTesting
#else
import CoreNetwork
#endif

@main
final class FeatureSearchDemoAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = FeatureSearchDemoAppDelegate.self
        return configuration
    }
}

final class FeatureSearchDemoSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let search: any FeatureSearchServing
        #if DEV
        search = FeatureSearchServingImpl(session: MockGithubSearchSession())
        #else
        search = FeatureSearchServingImpl(session: NetworkSession())
        #endif

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(
            rootViewController: search.makeSearchEntryViewController(actions: nil)
        )
        window.makeKeyAndVisible()
        self.window = window
    }
}

