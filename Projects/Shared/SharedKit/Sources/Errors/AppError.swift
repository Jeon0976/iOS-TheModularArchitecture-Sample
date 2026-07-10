//
//  AppError.swift
//  SharedKit
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

public enum CommonError: Error, Sendable, Equatable {
    case message(String)
    case unknown
}

public enum RepositoryError: Error, Sendable, Equatable {
    case network(NetworkError)
    case dataCorrupted
    case unauthorized
    case unknown
}

public enum DomainError: Error, Sendable, Equatable {
    case validation(message: String)
    case businessRule(message: String)
    case unknown
}

public enum AppError: Error, Sendable, Equatable {
    case network(NetworkError)
    case repository(RepositoryError)
    case domain(DomainError)
    case common(CommonError)
}

public protocol AppErrorConvertible {
    var asAppError: AppError { get }
}

public extension AppError {
    static func wrap(_ error: Error) -> AppError {
        switch error {
        case let appError as AppError: appError
        case let convertible as AppErrorConvertible: convertible.asAppError
        case let networkError as NetworkError: .network(networkError)
        case let repositoryError as RepositoryError: .repository(repositoryError)
        case let domainError as DomainError: .domain(domainError)
        case let commonError as CommonError: .common(commonError)
        default: .common(.unknown)
        }
    }
}
