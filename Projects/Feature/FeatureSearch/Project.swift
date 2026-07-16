import DependencyPlugin
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.module(
    name: ModulePaths.Feature.FeatureSearch.rawValue,
    targets: [
        .interface(
            module: .feature(.FeatureSearch),
            dependencies: [
                .shared(target: .SharedKit)
            ]
        ),
        .implements(
            module: .feature(.FeatureSearch),
            dependencies: [
                .feature(
                    target: .FeatureSearch,
                    type: .interface
                ),
                .shared(target: .SharedKit),
                .core(target: .CoreNetwork),
                .core(target: .CoreDesignSystem)
            ]
        ),
        .testing(
            module: .feature(.FeatureSearch),
            dependencies: [
                .feature(
                    target: .FeatureSearch,
                    type: .interface
                ),
                .shared(target: .SharedKit),
                .core(target: .CoreNetwork)
            ]
        ),
        .tests(
            module: .feature(.FeatureSearch),
            dependencies: [
                .feature(target: .FeatureSearch),
                .feature(
                    target: .FeatureSearch,
                    type: .testing
                ),
                .core(target: .CoreNetwork, type: .testing)
            ]
        ),
        .demo(
            module: .feature(.FeatureSearch),
            dependencies: [
                .feature(target: .FeatureSearch),
                .feature(
                    target: .FeatureSearch,
                    type: .testing
                ),
            ]
        ),
    ]
)
