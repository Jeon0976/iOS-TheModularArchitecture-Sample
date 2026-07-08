import ProjectDescription

public struct ProjectEnvironment: Sendable {
    public let name: String
    public let organizationName: String
    public let deploymentTargets: DeploymentTargets
    public let destinations: Destinations
    public let baseSwiftSettings: SettingsDictionary
    
    public func bundleId(_ suffix: String) -> String {
        "\(organizationName).\(suffix)"
    }
}

public let env = ProjectEnvironment(
    name: "GitSearchMicro",
    organizationName: "com.seonghun.gitsearchmicro",
    deploymentTargets: .iOS("16.0"),
    destinations: .iOS,
    baseSwiftSettings: [
        "SWIFT_VERSION": "6.0",
        "SWIFT_STRICT_CONCURRENCY": "complete"
    ]
)
