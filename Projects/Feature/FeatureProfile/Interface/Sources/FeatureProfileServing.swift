import UIKit

@MainActor
public protocol FeatureProfileServing: AnyObject {
    func makeProfileEntryViewController(actions: FeatureProfileCoordinatorActions?) -> UIViewController
}

@MainActor
public protocol FeatureProfileCoordinatorActions: AnyObject {
    func profileDidLogout()
}
