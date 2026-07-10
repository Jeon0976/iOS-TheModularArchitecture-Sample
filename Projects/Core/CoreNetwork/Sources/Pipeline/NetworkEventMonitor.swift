//
//  NetworkEventMonitor.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

public protocol NetworkEventMonitor: Sendable {
    /// 요청이 전송되기 직전 (adapt까지 끝난 최종 요청)
    func willSend(_ request: URLRequest, endpoint: some NetworkEndpoint)

    /// 응답 도착 직후 (상태 코드 검증 전 )
    func didReceive(data: Data, response: HTTPURLResponse, endpoint: some NetworkEndpoint)
}
