//
//  NetworkSession.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import SharedKit

public final class NetworkSession: NetworkRequesting, Sendable {
    private let session: URLSession
    private let interceptors: [any RequestInterceptor]
    private let monitors: [any NetworkEventMonitor]
    private let makeDecoder: @Sendable () -> JSONDecoder
    
    private let maxRetryCount: Int
    
    public init(
        session: URLSession = .shared,
        interceptors: [any RequestInterceptor] = [],
        monitors: [any NetworkEventMonitor] = [NetworkLogger()],
        makeDecoder: @Sendable @escaping () -> JSONDecoder = { JSONDecoder() },
        maxRetryCount: Int = 1
    ) {
        self.session = session
        self.interceptors = interceptors
        self.monitors = monitors
        self.makeDecoder = makeDecoder
        self.maxRetryCount = maxRetryCount
    }
    
    public func request<T, E>(
        _ endpoint: E,
        type: T.Type
    ) async throws -> T where T : Decodable, T : Sendable, E : NetworkEndpoint {
        let data = try await perform(endpoint)
        
        do {
            return try makeDecoder().decode(T.self, from: data)
        } catch {
            printIfDebug("디코딩 실패(\(T.self)): \(error)")
            
            throw NetworkError.decodingError
        }
    }
    
    public func requestWithNoContent<E>(_ endpoint: E) async throws where E : NetworkEndpoint {
        _ = try await perform(endpoint)
    }
    
    public func requestRawData<E>(_ endpoint: E) async throws -> Data where E : NetworkEndpoint {
        try await perform(endpoint)
    }
    
    // MARK: - 공통 파이프라인
    private func perform<E: NetworkEndpoint>(_ endpoint: E) async throws -> Data {
        var attempt = 0
        
        while true {
            do {
                return try await performOnce(endpoint)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                attempt += 1
                
                guard attempt <= maxRetryCount,
                        let delay = await retryDelay(
                            endpoint,
                            dueTo: error,
                            attempt: attempt
                        )
                else { throw error }
                
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
    }
    
    private func performOnce<E: NetworkEndpoint>(_ endpoint: E) async throws -> Data {
        let request = try prepareRequest(for: endpoint)
        
        for monitor in monitors {
            monitor.willSend(request, endpoint: endpoint)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            for monitor in monitors {
                monitor.didReceive(
                    data: data,
                    response: httpResponse,
                    endpoint: endpoint
                )
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw NetworkError.mapHTTPStatus(httpResponse.statusCode)
            }
            
            return data
        } catch let error as NetworkError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }
    
    // urlRequest위에 인터셉터들을 배열 순서대로 얹는다.
    func prepareRequest<E: NetworkEndpoint>(for endpoint: E) throws -> URLRequest {
        var request = try endpoint.urlRequest()
        
        for interceptor in interceptors {
            request = try interceptor.adapt(request, endpoint: endpoint)
        }
        
        return request
    }
    
    // 인터셉터들의 재시도 반영
    private func retryDelay<E: NetworkEndpoint>(
        _ endpoint: E,
        dueTo error: Error,
        attempt: Int
    ) async -> TimeInterval? {
        for interceptor in interceptors {
            if case .retry(let after) = await interceptor.retry(
                endpoint,
                dueTo: error,
                attempt: attempt
            ) {
                return after
            }
        }
        
        return nil
    }
    
    static func map(_ error: Error) -> Error {
        guard let urlError = error as? URLError else { return NetworkError.unknown }
        
        switch urlError.code {
        case .cancelled:
            return CancellationError()
        case .badURL:
            return NetworkError.invalidURL
        case .timedOut:
            return NetworkError.requestTimeout
        case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
            return NetworkError.badConnection
        default:
            return NetworkError.unknown
        }
    }
}
