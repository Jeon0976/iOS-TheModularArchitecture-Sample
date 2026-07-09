//
//  Project+Module.swift
//  Manifests
//
//  Created by 전성훈 on 7/8/26.
//

import ConfigurationPlugin
import DependencyPlugin
import EnvironmentPlugin
import ProjectDescription

public extension Product {
    static func module(
        name: String,
        packages: [Package] = [],
        settings: Settings? = nil,
        targets: [Target],
        additionalFiles: [FileElement] = []
    ) -> Project {
        Project(
            name: name,
            organizationName: env.organizationName,
            options: .options(
                automaticSchemesOptions: .disabled
            ),
            packages: packages,
            settings: settings ?? .settings(
                base: env.baseSwiftSettings,
                configurations: .default
            ),
            targets: targets,
            schemes: makeScehemes(
                name: name,
                targets: targets
            ),
            additionalFiles: additionalFiles
        )
    }
    
    // MARK: - Scheme 생성
    
    private static func makeScehemes(
        name: String,
        targets: [Target]
    ) -> [Scheme] {
        let buildTargetNames = targets.filter {
            $0.product != .unitTests
        }.map(\.name)
        
        let testTargetNames = targets.filter {
            $0.product == .unitTests
        }.map(\.name)
        
        let appTargetNames = targets.filter {
            $0.product == .app
        }.map(\.name)
        
        var schemes: [Scheme] = []
        
        // 1. 모듈 스킴
        schemes.append(
            .scheme(
                name: name,
                shared: true,
                buildAction: .buildAction(
                    targets: buildTargetNames.map { .target($0) }
                ),
                testAction:
                    testTargetNames.isEmpty ? nil : .targets(
                        testTargetNames.map {
                            .testableTarget(target: .target($0))
                        },
                        configuration: .dev,
                        options: .options(coverage: true)
                    )
            )
        )
        
        // 2. demo/app 단독 실행 스킴 (dep/prod 각각)
        for appTargetName in appTargetNames {
            for deploy in ProjectDeployTarget.allCases {
                schemes.append(
                    .scheme(
                        name: "\(appTargetName)-\(deploy.rawValue)",
                        shared: true,
                        buildAction: .buildAction(
                            targets: [.target(appTargetName)]),
                        runAction: .runAction(
                            configuration: deploy == .dev ? .dev : .prod,
                            executable: .target(appTargetName)
                        )
                    )
                )
            }
        }
        
        return schemes
    }
}
