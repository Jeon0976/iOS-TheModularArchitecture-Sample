import UIKit

import FeatureSearchInterface

@MainActor
public final class FeatureSearchServingImpl: FeatureSearchServing {
    public init() {}

    public func makeEntryViewController() -> UIViewController {
        // TODO: Domain/Data/Presentation을 여기서 조립한다.
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        viewController.title = "FeatureSearch"
        return viewController
    }
}
