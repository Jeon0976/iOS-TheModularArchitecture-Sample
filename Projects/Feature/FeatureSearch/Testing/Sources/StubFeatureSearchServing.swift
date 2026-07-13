
import UIKit

import FeatureSearchInterface

// Interface의 Mock — 다른 모듈의 테스트/Demo(DEV)가 재사용한다. Interface에만 의존한다.
@MainActor
public final class StubFeatureSearchServing: FeatureSearchServing {
    public private(set) var makeCallCount = 0
    public private(set) var lastActions: FeatureSearchCoordinatorActions?

    public init() {}
    
    public func makeSearchEntryViewController(
        actions: FeatureSearchCoordinatorActions?
    ) -> UIViewController {
        makeCallCount += 1
        lastActions = actions

        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        viewController.title = "Stub Search"

        return viewController
    }
}
