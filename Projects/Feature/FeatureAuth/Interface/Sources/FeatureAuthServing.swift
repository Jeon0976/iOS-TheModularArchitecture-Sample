import UIKit

@MainActor
public protocol FeatureAuthServing: AnyObject {
    var isLoggedIn: Bool { get }
    
    func makeLoginViewController(actions: FeatureAuthCoordinatorActions?) -> UIViewController
    
    
    /// OAuth 리다이렉트 URL 처리
    @discardableResult
    func handleOAuthCallback(_ url: URL) -> Bool
    
    func logout()
}

@MainActor
public protocol FeatureAuthCoordinatorActions: AnyObject {
    func authDidLogin()
}

