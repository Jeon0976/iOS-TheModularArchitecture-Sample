import UIKit

import FeatureAuthInterface
#if DEV
import FeatureAuthTesting
#else
import FeatureAuth
#endif

@main
final class FeatureAuthDemoAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let serving: any FeatureAuthServing
        #if DEV
        serving = StubFeatureAuthServing()
        #else
        serving = FeatureAuthServingImpl()
        #endif

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: serving.makeEntryViewController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
