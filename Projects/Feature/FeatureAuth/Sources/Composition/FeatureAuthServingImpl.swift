import UIKit

import FeatureAuthInterface

@MainActor
public final class FeatureAuthServingImpl: FeatureAuthServing {
    public init() {}

    public func makeEntryViewController() -> UIViewController {
        // TODO: Domain/Data/Presentation을 여기서 조립한다.
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        viewController.title = "FeatureAuth"
        return viewController
    }
}
