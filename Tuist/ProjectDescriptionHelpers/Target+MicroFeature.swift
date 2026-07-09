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
        TargetSpec(
            sources: .interface,
            dependencies: dependencies
        )
        .toTarget(
            with: module.targetName(type: .interface),
            product: env.moduleProduct
        )
    }
    
    // 2. 구현(Sources)
    static func implements(
        module: ModulePaths,
        product: Product = env.moduleProduct,
        resources: ResourceFileElements? = nil,
        dependencies: [TargetDependency] = []
    ) -> Target {
        TargetSpec(
            product: product,
            sources: .implementation,
            resources: resources,
            dependencies: dependencies
        )
        .toTarget(
            with: module.targetName(type: .sources),
            product: product
        )
    }
    
    // 3. Testing
    // Interface의 Mock
    static func testing(
        module: ModulePaths,
        dependencies: [TargetDependency] = []
    ) -> Target {
        TargetSpec(
            sources: .testing,
            dependencies: dependencies
        )
        .toTarget(
            with: module.targetName(type: .testing),
            product: .framework
        )
    }
    
    // 4. Tests
    static func tests(
        module: ModulePaths,
        dependencies: [TargetDependency] = []
    ) -> Target {
        TargetSpec(
            product: .unitTests,
            sources: .unitTests,
            dependencies: dependencies
        )
        .toTarget(
            with: module.targetName(type: .unitTest),
            product: .unitTests
        )
    }
    
    // 5. Demo
    static func demo(
        module: ModulePaths,
        dependencies: [TargetDependency] = []
    ) -> Target {
        let demoName = module.targetName(type: .demo)
        
        return TargetSpec(
            product: .app,
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": .dictionary([:]),
                "CFBundleDisplayName": .string(demoName)
            ]),
            sources: .demo,
            dependencies: dependencies
        )
        .toTarget(with: demoName, product: .app)
    }
    
}
