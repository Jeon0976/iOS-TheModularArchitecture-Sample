//
//  TargetDependency+Module.swift
//  Plugins
//
//  Created by 전성훈 on 7/8/26.
//

import ProjectDescription

// MARK: - 경로 해석 (레이어 -> Projects/(Layer) 디렉토리)

public extension ProjectDescription.Path {
    static func relativeToShared(_ path: String) -> Self {
        .relativeToRoot("Projects/Shared/\(path)")
    }
    
    static func relativeToCore(_ path: String) -> Self {
        .relativeToRoot("Projects/Core/\(path)")
    }
    
    static func relativeToFeature(_ path: String) -> Self {
        .relativeToRoot("Projects/Feature/\(path)")
    }
}

// MARK: - 의존 참조

public extension TargetDependency {
    static func shared(
        target: ModulePaths.Shared,
        type: MicroTargetType = .sources
    ) -> TargetDependency {
        .project(
            target: target.targetName(type: type),
            path: .relativeToShared(target.rawValue)
        )
    }
    
    static func core(
        target: ModulePaths.Core,
        type: MicroTargetType = .sources
    ) -> TargetDependency {
        .project(
            target: target.targetName(type: type),
            path: .relativeToCore(target.rawValue)
        )
    }
    
    static func feature(
        target: ModulePaths.Feature,
        type: MicroTargetType = .sources
    ) -> TargetDependency {
        .project(
            target: target.targetName(type: type),
            path: .relativeToFeature(target.rawValue)
        )
    }
}
