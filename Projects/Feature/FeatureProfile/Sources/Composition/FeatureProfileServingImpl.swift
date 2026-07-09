import UIKit

import FeatureProfileInterface

@MainActor
public final class FeatureProfileServingImpl: FeatureProfileServing {
    public init() {}

    public func makeEntryViewController() -> UIViewController {
        // TODO: Domain/Data/Presentation을 여기서 조립한다.
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        viewController.title = "FeatureProfile"
        return viewController
    }
}
