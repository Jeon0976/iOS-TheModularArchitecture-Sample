import ProjectDescription

let project = Project(
    name: "MicroFeatureArchitecture-GitSearch",
    targets: [
        .target(
            name: "MicroFeatureArchitecture-GitSearch",
            destinations: .iOS,
            product: .app,
            bundleId: "io.tuist.MicroFeatureArchitecture-GitSearch",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            sources: ["MicroFeatureArchitecture-GitSearch/Sources/**"],
            resources: ["MicroFeatureArchitecture-GitSearch/Resources/**"],
            dependencies: []
        ),
        .target(
            name: "MicroFeatureArchitecture-GitSearchTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "io.tuist.MicroFeatureArchitecture-GitSearchTests",
            infoPlist: .default,
            sources: ["MicroFeatureArchitecture-GitSearch/Tests/**"],
            resources: [],
            dependencies: [.target(name: "MicroFeatureArchitecture-GitSearch")]
        ),
    ]
)
