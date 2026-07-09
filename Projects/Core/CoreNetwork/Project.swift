//
//  Project.swift
//  Manifests
//
//  Created by 전성훈 on 7/9/26.
//

import DependencyPlugin
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.module(
    name: ModulePaths.Core.CoreNetwork.rawValue,
    targets: [
        .implements(
            module: .core(.CoreNetwork),
            dependencies: [
                .shared(target: .SharedKit),
                .core(target: .CoreStorage)
            ]
        ),
        .testing(
            module: .core(.CoreNetwork),
            dependencies: [
                .core(target: .CoreNetwork),
                .shared(target: .SharedKit),
                .core(target: .CoreStorage)
            ]
        ),
        .tests(
            module: .core(.CoreNetwork),
            dependencies: [
                .core(target: .CoreNetwork),
                .core(target: .CoreNetwork, type: .testing),
                .core(target: .CoreStorage, type: .testing)
            ]
        )
    ]
)
