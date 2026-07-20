import DependencyPlugin
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.module(
    name: ModulePaths.Feature.FeatureAuth.rawValue,
    targets: [
        .interface(
            module: .feature(.FeatureAuth),
            dependencies: [
                .shared(target: .SharedKit)
            ]
        ),
        .implements(
            module: .feature(.FeatureAuth),
            dependencies: [
                .feature(
                    target: .FeatureAuth,
                    type: .interface
                ),
                .shared(target: .SharedKit),
                .core(target: .CoreNetwork),
                .core(target: .CoreDesignSystem),
                .core(target: .CoreStorage)
            ]
        ),
        .testing(
            module: .feature(.FeatureAuth),
            dependencies: [
                .feature(
                    target: .FeatureAuth,
                    type: .interface
                ),
                .shared(target: .SharedKit),
                .core(target: .CoreNetwork)
            ]
        ),
        .tests(
            module: .feature(.FeatureAuth),
            dependencies: [
                .feature(target: .FeatureAuth),
                .feature(
                    target: .FeatureAuth,
                    type: .testing
                ),
            ]
        ),
        .demo(
            module: .feature(.FeatureAuth),
            dependencies: [
                .feature(target: .FeatureAuth),
                .feature(
                    target: .FeatureAuth,
                    type: .testing
                ),
                .core(target: .CoreStorage, type: .testing)
            ]
        ),
    ]
)
