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
                .feature(target: .FeatureProfile, type: .interface),
                .shared(target: .SharedKit),
                .core(target: .CoreNetwork),
                .core(target: .CoreDesignSystem),
                .feature(target: .FeatureAuth, type: .interface)
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
                .feature(target: .FeatureProfile,type: .testing),
                .core(target: .CoreNetwork, type: .testing),
                .feature(target: .FeatureAuth, type: .testing)
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
