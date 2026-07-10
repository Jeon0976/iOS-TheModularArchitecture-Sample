//
//  TransientErrorRetryInterceptor.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import SharedKit

public struct TransientErrorRetryInterceptor: RequestInterceptor {
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    
    public init(maxRetries: Int = 1, baseDelay: TimeInterval = 0.5) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }
    
    public func retry(
        _ endpoint: some NetworkEndpoint,
        dueTo error: any Error,
        attempt: Int
    ) async -> RetryDecision {
        // 1. 비멱등은 재시도 금지
        guard endpoint.isIdempotent else { return .doNotRetry }
        
        // 2. 자체 한도
        guard attempt <= maxRetries else { return .doNotRetry }
        
        // 3. 일시적 에러
        // 다시 보내면 결과가 달라질 가능성이 있는 실패
        guard Self.isTransient(error) else { return .doNotRetry }
        
        // 지수 백오프
        return .retry(after: baseDelay * pow(2, Double(attempt - 1)))
    }
    
    static func isTransient(_ error: Error) -> Bool {
        switch error as? NetworkError {
        case .badConnection, .requestTimeout, .invalidResponse: true
        default: false
        }
    }
}
