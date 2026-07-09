import ProjectDescription

public enum ModulePaths {
    case shared(Shared)
    case core(Core)
    case feature(Feature)
}

// MARK: - 5타겟 네이밍 (Interface / 구현 / Testing / Tests / Demo)

public enum MicroTargetType: String {
    case interface = "Interface"
    case sources = ""
    case testing = "Testing"
    case unitTest = "Tests"
    case demo = "Demo"
}

public protocol MicroTargetPathConvertable {
    func targetName(type: MicroTargetType) -> String
}

public extension MicroTargetPathConvertable where Self: RawRepresentable, Self.RawValue == String {
    func targetName(type: MicroTargetType) -> String {
        "\(rawValue)\(type.rawValue)"
    }
}

// MARK: - 레이어별 모듈 레지스트리

public extension ModulePaths {
    enum Shared: String, MicroTargetPathConvertable, CaseIterable {
        case SharedKit
    }
    
    enum Core: String, MicroTargetPathConvertable, CaseIterable {
        case CoreStorage
        case CoreNetwork
        case CoreDesignSystem
    }
    
    enum Feature: String, MicroTargetPathConvertable, CaseIterable {
        case FeatureSearch
        case FeatureAuth
        case FeatureProfile
    }
}

// MARK: - ModulePaths -> 타겟 이름 위임

public extension ModulePaths {
    func targetName(type: MicroTargetType) -> String {
        switch self {
        case
            let .shared(module as any MicroTargetPathConvertable),
            let .core(module as any MicroTargetPathConvertable),
            let .feature(module as any MicroTargetPathConvertable):
            
            return module.targetName(type: type)
        }
    }
}
