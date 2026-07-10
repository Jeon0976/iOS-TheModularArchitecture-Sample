//
//  ParameterEncoding.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

public protocol ParameterEncoding: Sendable {
    func encode(
        parameters: [String: String],
        into request: inout URLRequest
    ) throws
}
