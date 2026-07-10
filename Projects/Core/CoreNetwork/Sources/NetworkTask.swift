//
//  NetworkTask.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

public enum NetworkTask: Sendable {
    case requestPlain
    case requestData(Data)
    case requestJSONEncodable(any Encodable & Sendable)
    case requestParameters(parameters: [String: String], encoding: any ParameterEncoding)
}
