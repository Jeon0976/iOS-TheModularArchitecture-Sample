
import UIKit

import FeatureProfileInterface

// Interface의 Mock — 다른 모듈의 테스트/Demo(DEV)가 재사용한다. Interface에만 의존한다.
@MainActor
public final class StubFeatureProfileServing: FeatureProfileServing {
    
    public private(set) var makeCallCount = 0
    public init() {}
    
    public func makeProfileEntryViewController(
        actions: FeatureProfileCoordinatorActions?
    ) -> UIViewController {
        makeCallCount += 1
        
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        viewController.title = "Stub FeatureProfile"
        
        return viewController
    }
}
