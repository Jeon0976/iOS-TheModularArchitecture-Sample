//
//  NetworkError+HTTPStatus.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import SharedKit

extension NetworkError {
    public static func mapHTTPStatus(_ statusCode: Int) -> NetworkError {
        switch statusCode {
        case 400: .requestFailed
        case 401: .tokenExceeded
        case 403, 429: .apiRateLimitExceeded
        case 404: .invalidURL
        case 408: .requestTimeout
        case 500...599: .invalidResponse
        default: .unknown
        }
    }
}
