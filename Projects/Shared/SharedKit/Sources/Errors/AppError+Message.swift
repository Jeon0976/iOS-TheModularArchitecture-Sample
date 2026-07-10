//
//  AppError+Message.swift
//  SharedKit
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

public extension AppError {
    var message: String {
        switch self {
        case .network(let error): Self.networkMessage(error)
        case .repository(let error):
            switch error {
            case .network(let networkError): Self.networkMessage(networkError)
            case .unauthorized: "다시 로그인해주세요."
            case .dataCorrupted: "데이터를 불러오지 못했어요."
            case .unknown: "문제가 발생했어요. 잠시 후 다시 시도해주세요."
            }
        case .domain(let error):
            switch error {
            case .validation(let message): message
            case .businessRule(let message): message
            case .unknown: "요청을 처리할 수 없어요."
            }
        case .common(let error):
            switch error {
            case .message(let message): message
            case .unknown: "알 수 없는 오류가 발생했어요."
            }
        }
    }

    private static func networkMessage(_ error: NetworkError) -> String {
        switch error {
        case .badConnection: "네트워크 연결을 확인해주세요."
        case .requestTimeout: "요청 시간이 초과됐어요. 다시 시도해주세요."
        case .apiRateLimitExceeded: "요청이 많습니다. 잠시 후 다시 시도해주세요."
        case .tokenExceeded: "다시 로그인해주세요."
        case .decodingError, .noData, .invalidResponse: "서버 응답을 처리하지 못했어요."
        default: "네트워크 오류가 발생했어요."
        }
    }
}
