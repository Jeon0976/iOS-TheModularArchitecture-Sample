import UIKit

import CoreStorage
import FeatureAuthInterface
import FeatureProfile
import FeatureProfileInterface
#if DEV
import CoreStorageTesting
import FeatureProfileTesting
#else
import CoreNetwork
#endif

@main
final class ProfileDemoAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        
        configuration.delegateClass = ProfileDemoAppDelegate.self
        
        return configuration
    }
}

final class ProfileDemoSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let profile: any FeatureProfileServing
        #if DEV
        profile = FeatureProfileServingImpl(
            session: MockGithubUserSession(),
            auth: DemoAuthStub(tokenStorage: MockTokenStorage())
        )
        #else
        let tokenStorage = KeychainTokenStorage()
        let session = NetworkSession(
            interceptors: [
                AuthTokenInterceptor(tokenStorage: tokenStorage),
                TransientErrorRetryInterceptor(),
            ]
        )
        profile = FeatureProfileServingImpl(
            session: session,
            auth: DemoAuthStub(tokenStorage: tokenStorage)
        )
        #endif

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(
            rootViewController: profile.makeProfileEntryViewController(actions: nil)
        )
        window.makeKeyAndVisible()
        self.window = window
    }
}

@MainActor
private final class DemoAuthStub: FeatureAuthServing {
    private let tokenStorage: any TokenStorage

    init(tokenStorage: any TokenStorage) {
        self.tokenStorage = tokenStorage
    }

    var isLoggedIn: Bool { tokenStorage.retrieve() != nil }

    func makeLoginViewController(
        actions: FeatureAuthCoordinatorActions?
    ) -> UIViewController {
        UIViewController()
    }

    func handleOAuthCallback(_ url: URL) -> Bool { false }

    func logout() {
        tokenStorage.clear()
    }
}
