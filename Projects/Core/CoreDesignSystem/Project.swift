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
    name: ModulePaths.Core.CoreDesignSystem.rawValue,
    targets: [
        .implements(module: .core(.CoreDesignSystem)),
        .testing(
            module: .core(.CoreDesignSystem),
            dependencies: [.core(target: .CoreDesignSystem)]
        ),
        .tests(
            module: .core(.CoreDesignSystem),
            dependencies: [
                .core(target: .CoreDesignSystem),
                .core(target: .CoreDesignSystem, type: .testing)
            ]
        ),
        .demo(
            module: .core(.CoreDesignSystem),
            dependencies: [
                .core(target: .CoreDesignSystem),
                .core(target: .CoreDesignSystem, type: .testing)
            ]
        )
    ]
)
