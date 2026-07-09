import UIKit

/// FeatureProfile 공개 protocol / 다른 피처·App이 보는 유일한 창구
@MainActor
public protocol FeatureProfileServing {
    func makeEntryViewController() -> UIViewController
}

