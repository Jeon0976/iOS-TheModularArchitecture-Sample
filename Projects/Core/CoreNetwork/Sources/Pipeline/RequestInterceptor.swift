//
//  RequestInterceptor.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation
 
/// 실패한 요청을 다시 보낼지에 대한 인터셉터
public enum RetryDecision: Sendable, Equatable {
    case doNotRetry
    case retry(after: TimeInterval)
}

public protocol RequestInterceptor: Sendable {
    func adapt(_ request: URLRequest, endpoint: some NetworkEndpoint) throws -> URLRequest
    func retry(_ endpoint: some NetworkEndpoint, dueTo error: Error, attempt: Int) async -> RetryDecision
}

extension RequestInterceptor {
    public func adapt(
        _ request: URLRequest,
        endpoint: some NetworkEndpoint
    ) throws -> URLRequest {
        request
    }

    public func retry(
        _ endpoint: some NetworkEndpoint,
        dueTo error: Error,
        attempt: Int
    ) async -> RetryDecision {
        .doNotRetry
    }
}
