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
final class AuthDemoAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    private var auth: (any FeatureAuthServing)?
    
#if DEV
    private var demoActions: DemoAuthActions?
    private var didLeaveApp = false
#endif
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        let auth: any FeatureAuthServing
        
#if DEV
        auth = FeatureAuthServingImpl(
            session: MockGithubAuthSession(),
            tokenStorage: MockTokenStorage(),
            credentials: OAuthCredentials(
                clientID: "demo_client_id",
                clientSecret: "demo_secret"
            )
        )
#else
        auth = FeatureAuthServingImpl(
            session: NetworkSession(),
            tokenStorage: KeychainTokenStorage(account: "demo.auth.token"),
            credentials: nil
        )
#endif
        self.auth = auth
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        
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
        
        return true
    }
    
#if DEV
    func applicationWillResignActive(_ application: UIApplication) {
        // 로그인 버튼 -> 사파리로 나가는 순간
        didLeaveApp = true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // 첫 구동의 becomeActive는 제외
        guard didLeaveApp else { return }
        didLeaveApp = false
        
        // GitHub이 findusername://…?code=… 로 리다이렉트해 주는 구간의 시뮬레이션 —
        // 실 앱에서는 SceneDelegate가 URL을 받아 이 호출을 한다.
        // 콜백 파싱이 "이름으로 찾기"(URLComponents)임을 데모에서도 확인하는 셈
        let callback = URL(string: "\(AuthCallback.scheme)://callback?code=demo-authorization-code&state=demo")!
        auth?.handleOAuthCallback(callback)
    }
#endif
}

#if DEV
/// 로그인 성공을 눈으로 확인시키는 데모 액션
/// 실제 앱에서는 App(Composition Root)이 이 자리에서
/// 루트를 탭바로 갈아끼운다. 데모는 화면이 하나뿐이라 알럿으로 대신한다.
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

