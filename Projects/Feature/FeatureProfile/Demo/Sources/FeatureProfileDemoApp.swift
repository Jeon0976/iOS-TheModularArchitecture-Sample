import UIKit

import FeatureProfileInterface
#if DEV
import FeatureProfileTesting
#else
import FeatureProfile
#endif

@main
final class FeatureProfileDemoAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let serving: any FeatureProfileServing
        #if DEV
        serving = StubFeatureProfileServing()
        #else
        serving = FeatureProfileServingImpl()
        #endif

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: serving.makeEntryViewController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
