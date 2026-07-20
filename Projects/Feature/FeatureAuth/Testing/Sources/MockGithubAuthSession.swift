//
//  MockGithubAuthSession.swift
//  FeatureAuth
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreNetwork
import SharedKit

public final class MockGithubAuthSession: NetworkRequesting, Sendable {
    private let latency: Duration

    public init(latency: Duration = .milliseconds(600)) {
        self.latency = latency
    }

    public func request<T: Decodable & Sendable, E: NetworkEndpoint>(
        _ endpoint: E,
        type: T.Type
    ) async throws -> T {
        try? await Task.sleep(for: latency)

        let json = Data("""
        {"access_token": "gho_demo_0123456789abcdef", "token_type": "bearer", "scope": "user"}
        """.utf8)

        return try JSONDecoder().decode(T.self, from: json)
    }

    public func requestWithNoContent<E: NetworkEndpoint>(_ endpoint: E) async throws {
        try? await Task.sleep(for: latency)
    }

    public func requestRawData<E: NetworkEndpoint>(_ endpoint: E) async throws -> Data {
        throw NetworkError.noData
    }
}
