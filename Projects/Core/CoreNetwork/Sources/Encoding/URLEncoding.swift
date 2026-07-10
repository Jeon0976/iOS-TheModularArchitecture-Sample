//
//  URLEncoding.swift
//  CoreNetwork
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import SharedKit

public struct URLEncoding: ParameterEncoding {
    enum Destination: Sendable {
        case queryString
        case httpBody
    }
    
    let destination: Destination
    
    init(_ destination: Destination = .queryString) {
        self.destination = destination
    }
    
    public static let queryString = URLEncoding(.queryString)
    public static let httpBody = URLEncoding(.httpBody)
    
    public func encode(parameters: [String : String], into request: inout URLRequest) throws {
        guard let url = request.url else { throw NetworkError.invalidURL }

        // key=value&key=value 형태로 직렬화 — 키와 값 모두 이스케이프를 거친다.
        let encodedPairs = parameters
            .map { "\(Self.escape($0.key))=\(Self.escape($0.value))" }
            .joined(separator: "&")

        switch destination {
        case .queryString:
            if var urlComponents = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            ) {
                // 기존 쿼리가 있으면 & 로 이어붙인다 (덮어쓰지 않음)
                let percentEncodedQuery = urlComponents.percentEncodedQuery.map { $0 + "&" } ?? ""
                urlComponents.percentEncodedQuery = percentEncodedQuery + encodedPairs
                request.url = urlComponents.url
            }
        case .httpBody:
            request.httpBody = encodedPairs.data(using: .utf8)
            
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "Content-Type"
                )
            }
        }
    }
    
    private static let allowedCharacters: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?/")
        return allowed
    }()

    private static func escape(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? string
    }
}
