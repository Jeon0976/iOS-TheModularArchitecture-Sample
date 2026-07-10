//
//  NetworkEndpoint.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

public protocol NetworkEndpoint: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var task: NetworkTask { get }
    var headers: [String: String]? { get }
    var requiresAuth: Bool { get }
    var isIdempotent: Bool { get }
}

extension NetworkEndpoint {
    public var requriesAuth: Bool { true }
    
    public var isIdempotent: Bool {
        switch method {
        case .get, .put, .delete: true
        case .post, .patch: false
        }
    }
    
    public var headers: [String: String]? { nil }

    func url() -> URL {
        path.isEmpty ? baseURL : baseURL.appending(path: path)
    }
    
    func urlRequest() throws -> URLRequest {
        var request = URLRequest(url: url())
        request.httpMethod = method.rawValue

        if let headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        switch task {
        case .requestPlain:
            break
        case .requestData(let data):
            request.httpBody = data
        case .requestJSONEncodable(let encodable):
            request.httpBody = try JSONEncoder().encode(encodable)
            
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        case .requestParameters(let parameters, let encoding):
            try encoding.encode(parameters: parameters, into: &request)
        }
        
        return request
    }
}
