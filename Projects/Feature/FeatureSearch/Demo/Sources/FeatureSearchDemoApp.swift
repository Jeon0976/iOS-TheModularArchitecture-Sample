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
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let serving: any FeatureSearchServing
        #if DEV
        serving = FeatureSearchServingImpl(session: MockGithubSearchSession())
        #else
        serving = FeatureSearchServingImpl(session: NetworkSession())
        #endif

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(
            rootViewController: serving.makeSearchEntryViewController(actions: nil)
        )
        window.makeKeyAndVisible()
        
        self.window = window
        return true
    }
}
