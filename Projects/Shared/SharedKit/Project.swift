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
    name: ModulePaths.Shared.SharedKit.rawValue,
    targets: [
        .implements(module: .shared(.SharedKit)),
        .testing(
            module: .shared(.SharedKit),
            dependencies: [.shared(target: .SharedKit)]
        ),
        .tests(
            module: .shared(.SharedKit),
            dependencies: [
                .shared(target: .SharedKit),
                .shared(target: .SharedKit, type: .testing)
            ]
        )
    ]
)
