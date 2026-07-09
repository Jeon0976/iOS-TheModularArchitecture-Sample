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
    name: ModulePaths.Core.CoreStorage.rawValue,
    targets: [
        .implements(module: .core(.CoreStorage)),
        .testing(
            module: .core(.CoreStorage),
            dependencies: [.core(target: .CoreStorage)]
        ),
        .tests(
            module: .core(.CoreStorage),
            dependencies: [
                .core(target: .CoreStorage),
                .core(target: .CoreStorage, type: .testing)
            ]
        )
    ]
)
