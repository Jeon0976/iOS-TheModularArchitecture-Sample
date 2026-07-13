//
//  StubNetworkRequesting.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreNetwork
import SharedKit

public final class StubNetworkRequesting: NetworkRequesting, @unchecked Sendable {
    private let lock = NSLock()
    
    private var _result: Result<Any, Error> = .failure(NetworkError.noData)
    private var _requestedEndpoints: [any NetworkEndpoint] = []
    
    public init() { }
    
    public var result: Result<Any, Error> {
        get { lock.lock(); defer { lock.unlock() }; return _result }
        set { lock.lock(); defer { lock.unlock() }; _result = newValue }
    }
    
    public var requestedEndpoints: [any NetworkEndpoint] {
        lock.lock(); defer { lock.unlock() }; return _requestedEndpoints
    }
    
    public func request<T: Decodable & Sendable, E: NetworkEndpoint>(
        _ endpoint: E,
        type: T.Type
    ) async throws -> T {
        switch record(endpoint) {
        case .success(let value):
            guard let typed = value as? T else {
                throw NetworkError.decodingError
            }
            return typed
        case .failure(let error):
            throw error
        }
    }

    public func requestWithNoContent<E: NetworkEndpoint>(_ endpoint: E) async throws {
        if case .failure(let error) = record(endpoint) { throw error }
    }

    public func requestRawData<E: NetworkEndpoint>(_ endpoint: E) async throws -> Data {
        switch record(endpoint) {
        case .success(let value):
            guard let data = value as? Data else {
                throw NetworkError.decodingError
            }
            return data
        case .failure(let error):
            throw error
        }
    }

    private func record(_ endpoint: any NetworkEndpoint) -> Result<Any, Error> {
        lock.withLock {
            _requestedEndpoints.append(endpoint)
            return _result
        }
    }

}
