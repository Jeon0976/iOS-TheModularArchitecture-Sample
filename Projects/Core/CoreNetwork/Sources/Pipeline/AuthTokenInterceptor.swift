//
//  AuthTokenInterceptor.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/12/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreStorage

public struct AuthTokenInterceptor: RequestInterceptor {
    private let tokenStorage: any TokenStorage
    
    public init(tokenStorage: any TokenStorage) {
        self.tokenStorage = tokenStorage
    }
    
    public func adapt(
        _ request: URLRequest,
        endpoint: some NetworkEndpoint
    ) throws -> URLRequest {
        guard endpoint.requiresAuth, let token = tokenStorage.retrieve() else {
            return request
        }
        
        var request = request
        
        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )
        
        return request
    }
}
