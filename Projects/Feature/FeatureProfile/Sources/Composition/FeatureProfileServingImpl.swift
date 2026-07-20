import UIKit

import FeatureProfileInterface

@MainActor
public final class FeatureProfileServingImpl: FeatureProfileServing {
    public init() {}

    public func makeProfileEntryViewController(
        actions: FeatureProfileCoordinatorActions?
    ) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        viewController.title = "FeatureProfile"
        return viewController
    }
}
