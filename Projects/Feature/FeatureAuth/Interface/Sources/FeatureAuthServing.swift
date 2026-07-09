import UIKit

/// FeatureAuth 공개 protocol / 다른 피처·App이 보는 유일한 창구
@MainActor
public protocol FeatureAuthServing {
    func makeEntryViewController() -> UIViewController
}

