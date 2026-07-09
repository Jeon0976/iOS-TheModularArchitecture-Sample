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

let featureDependencies: [TargetDependency] = ModulePaths.Feature.allCases.flatMap { feature in
    [
        TargetDependency.feature(target: feature),
        TargetDependency.feature(target: feature, type: .interface)
    ]
}

