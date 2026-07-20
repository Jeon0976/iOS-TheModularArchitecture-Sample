//
//  Project.swift
//  Manifests
//
//  Created by 전성훈 on 7/9/26.
//

import DependencyPlugin
import EnvironmentPlugin
import ProjectDescription
import ProjectDescriptionHelpers

let appName: String = "GitSearchApp"

let featureDependencies: [TargetDependency] = ModulePaths.Feature.allCases.flatMap { feature in
    [
        TargetDependency.feature(target: feature),
        TargetDependency.feature(target: feature, type: .interface)
    ]
}

let appTarget: Target = TargetSpec(
    product: .app,
    bundleId: env.bundleId("app"),
    infoPlist: .extendingDefault(with: [
        "UILaunchScreen": .dictionary([:]),
        "CFBundleDisplayName": .string("GitSearch"),
        "UIApplicationSceneManifest": .dictionary(["UIApplicationSupportsMultipleScenes": .boolean(false)]),
        "CFBundleURLTypes": .array([
            .dictionary([
                "CFBundleTypeRole": .string("Editor"),
                "CFBundleURLName": .string("com.seonghun.gitsearchmicro"),
                "CFBundleURLSchemes": .array([.string("findusername")]),
            ]),
        ]),
        "GithubClientID": .string("$(GITHUB_CLIENT_ID)"),
        "GithubClientSecret": .string("$(GITHUB_CLIENT_SECRET)")
    ]),
    sources: .implementation,
    dependencies: featureDependencies + [
        .core(target: .CoreNetwork),
        .core(target: .CoreStorage),
        .core(target: .CoreDesignSystem),
        .shared(target: .SharedKit)
    ],
    settings: .settings(
        base: env.baseSwiftSettings,
        configurations: .app
    )
).toTarget(with: appName, product: .app)

let project = Project.module(
    name: appName,
    settings: .settings(
        base: env.baseSwiftSettings,
        configurations: .app
    ),
    targets: [appTarget]
)
