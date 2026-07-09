//
//  Workspace.swift
//  Manifests
//
//  Created by 전성훈 on 7/8/26.
//

import DependencyPlugin
import ProjectDescription

let workspace = Workspace(
    name: "GitSearchMicroFeature",
    projects:
        ModulePaths.Shared.allCases.map { .relativeToShared($0.rawValue) }
    + ModulePaths.Core.allCases.map { .relativeToCore($0.rawValue) }
    + ModulePaths.Feature.allCases.map { .relativeToFeature($0.rawValue )}
    + [.relativeToRoot("Projects/App/GitSearchApp")]
)
