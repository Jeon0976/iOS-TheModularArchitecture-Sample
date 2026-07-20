import UIKit

import FeatureAuth
import FeatureAuthInterface
#if DEV
import CoreStorageTesting
import FeatureAuthTesting
#else
import CoreNetwork
import CoreStorage
#endif

@main
final class FeatureAuthDemoAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = FeatureAuthDemoSceneDelegate.self
        return configuration
    }
}

final class FeatureAuthDemoSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var auth: (any FeatureAuthServing)?

    #if DEV
    private var demoActions: DemoAuthActions?
    /// "사파리로 나갔다 돌아옴"을 GitHub 승인 완료로 치는 플래그 (아래 sceneDidBecomeActive 참고).
    private var didLeaveApp = false
    #endif

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let auth: any FeatureAuthServing
        #if DEV
        auth = FeatureAuthServingImpl(
            session: MockGithubAuthSession(),
            tokenStorage: MockTokenStorage(),
            credentials: OAuthCredentials(clientID: "demo_client_id", clientSecret: "demo_secret")
        )
        #else
        auth = FeatureAuthServingImpl(
            session: NetworkSession(),
            tokenStorage: KeychainTokenStorage(account: "demo.auth.token"),
            credentials: nil
        )
        #endif
        self.auth = auth

        let window = UIWindow(windowScene: windowScene)

        #if DEV
        let actions = DemoAuthActions(window: window)
        demoActions = actions
        window.rootViewController = UINavigationController(
            rootViewController: auth.makeLoginViewController(actions: actions)
        )
        #else
        window.rootViewController = UINavigationController(
            rootViewController: auth.makeLoginViewController(actions: nil)
        )
        #endif

        window.makeKeyAndVisible()
        self.window = window
    }

    /// 딥링크 수신
    /// findusername:// 콜백이 여기로 들어와 왕복이 완성된다.
    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        guard let url = URLContexts.first?.url else { return }
        auth?.handleOAuthCallback(url)
    }

    #if DEV
    func sceneWillResignActive(_ scene: UIScene) {
        didLeaveApp = true
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // 첫 구동의 becomeActive는 제외
        guard didLeaveApp else { return }
        didLeaveApp = false

        let callback = URL(string: "\(AuthCallback.scheme)://callback?code=demo-authorization-code&state=demo")!
        auth?.handleOAuthCallback(callback)
    }
    #endif
}


#if DEV
/// 로그인 성공을 눈으로 확인시키는 데모 액션
@MainActor
private final class DemoAuthActions: FeatureAuthCoordinatorActions {
    private weak let window: UIWindow?
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func authDidLogin() {
        let alert = UIAlertController(
            title: "로그인 성공",
            message: "목 세션이 발급한 토큰이 저장됐다.\n실 앱이라면 여기서 탭바로 전환한다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        window?.rootViewController?.present(alert, animated: true)
    }
}
#endif

