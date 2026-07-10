//
//  JSONEncoding.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import SharedKit

public struct JSONEncoding: ParameterEncoding {
    public static let `default`: JSONEncoding = .init()
    
    public func encode(
        parameters: [String: String],
        into request: inout URLRequest
    ) throws {
        do {
            let data = try JSONSerialization.data(withJSONObject: parameters)
            
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            request.httpBody = data
        } catch {
            throw NetworkError.invalidParameters
        }
    }
    
}
