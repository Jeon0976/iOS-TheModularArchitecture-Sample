//
//  NetworkRequesting.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

public protocol NetworkRequesting: Sendable {
    func request<T: Decodable & Sendable, E: NetworkEndpoint>(_ endpoint: E, type: T.Type) async throws -> T
    func requestWithNoContent<E: NetworkEndpoint>(_ endpoint: E) async throws
    func requestRawData<E: NetworkEndpoint>(_ endpoint: E) async throws -> Data
}
