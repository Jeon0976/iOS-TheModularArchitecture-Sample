import DependencyPlugin
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.module(
    name: ModulePaths.Feature.FeatureProfile.rawValue,
    targets: [
        .interface(
            module: .feature(.FeatureProfile),
            dependencies: [
                .shared(target: .SharedKit)
            ]
        ),
        .implements(
            module: .feature(.FeatureProfile),
            dependencies: [
                .feature(
                    target: .FeatureProfile,
                    type: .interface
                ),
                .shared(target: .SharedKit),
                .core(target: .CoreNetwork),
                .core(target: .CoreDesignSystem)
            ]
        ),
        .testing(
            module: .feature(.FeatureProfile),
            dependencies: [
                .feature(
                    target: .FeatureProfile,
                    type: .interface
                ),
                .shared(target: .SharedKit)
            ]
        ),
        .tests(
            module: .feature(.FeatureProfile),
            dependencies: [
                .feature(target: .FeatureProfile),
                .feature(
                    target: .FeatureProfile,
                    type: .testing
                ),
            ]
        ),
        .demo(
            module: .feature(.FeatureProfile),
            dependencies: [
                .feature(target: .FeatureProfile),
                .feature(
                    target: .FeatureProfile,
                    type: .testing
                ),
            ]
        ),
    ]
)
