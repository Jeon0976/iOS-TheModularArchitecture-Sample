//
//  Target+MicroFeature.swift
//  Manifests
//
//  Created by 전성훈 on 7/8/26.
//

import DependencyPlugin
import EnvironmentPlugin
import ProjectDescription

public extension Target {
    // 1. Interface - 이 모듈에 바깥에 보여준다.
    static func interface(module: ModulePaths, dependencies: [TargetDependency] = []) -> Target {
    }
}
