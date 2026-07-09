//
//  TargetSpec.swift
//  Manifests
//
//  Created by 전성훈 on 7/8/26.
//

import ConfigurationPlugin
import EnvironmentPlugin
import ProjectDescription

public struct TargetSpec: Configurable {
    public var destinations: Destinations
    public var product: Product
    public var bundleId: String?
    public var deploymentTargets: DeploymentTargets?
    public var infoPlist: InfoPlist?
    public var sources: SourceFilesList?
    public var resources: ResourceFileElements?
    public var scripts: [TargetScript]
    public var dependencies: [TargetDependency]
    public var settings: Settings?
    
    public init(
        destinations: Destinations = env.destinations,
        product: Product = .framework,
        bundleId: String? = nil,
        deploymentTargets: DeploymentTargets? = env.deploymentTargets,
        infoPlist: InfoPlist? = .default,
        sources: SourceFilesList? = nil,
        resources: ResourceFileElements? = nil,
        scripts: [TargetScript] = [],
        dependencies: [TargetDependency] = [],
        settings: Settings? = nil
    ) {
        self.destinations = destinations
        self.product = product
        self.bundleId = bundleId
        self.deploymentTargets = deploymentTargets
        self.infoPlist = infoPlist
        self.sources = sources
        self.resources = resources
        self.scripts = scripts
        self.dependencies = dependencies
        self.settings = settings
    }
    
    // 스펙 + 타겟 이름 -> 실제 target, bundleId, Settings 기본값을 여기서 채운다.
    public func toTarget(
        with name: String,
        product: Product? = nil
    ) -> Target {
        .target(
            name: name,
            destinations: destinations,
            product: product ?? self.product,
            bundleId: bundleId ?? env.bundleId(name.lowercased()),
            deploymentTargets: deploymentTargets,
            infoPlist: infoPlist ?? .default,
            sources: sources,
            resources: resources,
            scripts: scripts,
            dependencies: dependencies,
            settings: settings ?? .settings(
                base: env.baseSwiftSettings,
                configurations: .default
            )
        )
    }
}
