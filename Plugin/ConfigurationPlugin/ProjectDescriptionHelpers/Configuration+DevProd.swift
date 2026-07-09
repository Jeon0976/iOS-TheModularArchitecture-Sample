import ProjectDescription

public enum ProjectDeployTarget: String, CaseIterable {
    case dev = "DEV"
    case prod = "PROD"
}

public extension ConfigurationName {
    static var dev: ConfigurationName {
        .configuration(ProjectDeployTarget.dev.rawValue)
    }
    
    static var prod: ConfigurationName {
        .configuration(ProjectDeployTarget.prod.rawValue)
    }
}

// MARK: - XCConfig 경로

public extension ProjectDescription.Path {
    // 전 타겟 공통 빌드 설정
    static var sharedXCConfig: ProjectDescription.Path {
        .relativeToRoot("XCConfig/Shared.xcconfig")
    }
    
    // App 전용 (DEV/PROD) - 시크릿 include 경로
    static func appXCConfig(_ target: ProjectDeployTarget) -> ProjectDescription.Path {
        .relativeToRoot("XCConfig/App/\(target.rawValue).xcconfig")
    }
}

// MARK: - 기본 설정 배열 (모든 타겟, 프로젝트가 이걸 사용)

public extension Array where Element == Configuration {
    static var `default`: [Configuration] {
        [
            .debug(
                name: .dev,
                settings: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS":"$(inherited) DEV"
                ],
                xcconfig: .sharedXCConfig
            ),
            .release(
                name: .prod,
                xcconfig: .sharedXCConfig
            )
        ]
    }
    
    static var app: [Configuration] {
        [
            .debug(
                name: .dev,
                settings: [
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) DEV"
                ],
                xcconfig: .appXCConfig(.dev)
            ),
            .release(
                name: .prod,
                xcconfig: .appXCConfig(.prod)
            ),
        ]
    }
}
