//
//  NetworkLogger.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import SharedKit

public struct NetworkLogger: NetworkEventMonitor {
    public init() {}

    public func willSend(_ request: URLRequest, endpoint: some NetworkEndpoint) {
        let url = request.url?.absoluteString ?? "unknown url"
        let method = request.httpMethod ?? "unknown method"

        var httpLog = """
                       [HTTP Request]
                       URL: \(url)
                       TARGET: \(String(describing: endpoint))
                       METHOD: \(method)\n
                       """
        httpLog.append("HEADER: [\n")
        request.allHTTPHeaderFields?.forEach {
            httpLog.append("\t\($0): \($1)\n")
        }
        httpLog.append("]\n")

        if let body = request.httpBody,
           let bodyString = String(bytes: body, encoding: .utf8) {
            httpLog.append("BODY: \n\(bodyString)\n")
        }
        httpLog.append("[HTTP Request End]")

        printIfDebug(httpLog)
    }

    public func didReceive(
        data: Data,
        response: HTTPURLResponse,
        endpoint: some NetworkEndpoint
    ) {
        let url = response.url?.absoluteString ?? "nil"

        var httpLog = """
                       [HTTP Response]
                       TARGET: \(String(describing: endpoint))
                       URL: \(url)
                       STATUS CODE: \(response.statusCode)\n
                       """
        httpLog.append("HEADER: [\n")
        response.allHeaderFields.forEach {
            httpLog.append("\t\($0): \($1)\n")
        }
        httpLog.append("]\n")

        httpLog.append("RESPONSE DATA: \n")
        if let responseString = String(bytes: data, encoding: .utf8) {
            httpLog.append("\(responseString)\n")
        }
        httpLog.append("[HTTP Response End]")

        printIfDebug(httpLog)
    }
}
