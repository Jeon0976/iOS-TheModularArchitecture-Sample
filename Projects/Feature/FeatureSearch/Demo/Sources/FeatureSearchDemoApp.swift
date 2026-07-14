import UIKit

import FeatureSearchInterface
#if DEV
import FeatureSearchTesting
#else
import FeatureSearch
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
        serving = StubFeatureSearchServing()
        #else
        serving = FeatureSearchServingImpl()
        #endif

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: serving.makeSearchEntryViewController(actions: nil))
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
