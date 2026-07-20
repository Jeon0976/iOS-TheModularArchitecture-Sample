
import UIKit

import FeatureAuthInterface

@MainActor
public final class StubAuthServing: FeatureAuthServing {
    public var isLoggedIn: Bool

    public private(set) var logoutCallCount = 0
    public private(set) var handledURLs: [URL] = []

    public init(isLoggedIn: Bool = true) {
        self.isLoggedIn = isLoggedIn
    }

    public func makeLoginViewController(actions: FeatureAuthCoordinatorActions?) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        viewController.title = "Stub Login"

        return viewController
    }

    @discardableResult
    public func handleOAuthCallback(_ url: URL) -> Bool {
        handledURLs.append(url)
        return url.scheme == AuthCallback.scheme
    }

    public func logout() {
        logoutCallCount += 1
        isLoggedIn = false
    }
}

