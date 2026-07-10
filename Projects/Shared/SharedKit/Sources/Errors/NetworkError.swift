//
//  NetworkError.swift
//  SharedKit
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

public enum NetworkError: Error, Sendable, Equatable {
    case invalidURL
    case badConnection
    case invalidResponse
    case requestFailed
    case requestTimeout
    case noData
    case decodingError
    case apiRateLimitExceeded
    case tokenExceeded
    case invalidParameters
    case unknown
    
    public var description: String {
        switch self {
        case .invalidURL: "Invalid URL"
        case .badConnection: "Bad Connection"
        case .invalidResponse: "Invalid Response"
        case .requestFailed: "Network request failed"
        case .requestTimeout: "Request timed out."
        case .noData: "No data received"
        case .decodingError: "Error decoding data"
        case .apiRateLimitExceeded: "API Rate Limit Exceeded"
        case .tokenExceeded: "Token exceeded"
        case .invalidParameters: "Invalid Parameters"
        case .unknown: "Unknown Error"
        }
    }

}
