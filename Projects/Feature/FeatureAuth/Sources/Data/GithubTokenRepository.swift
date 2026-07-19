//
//  GithubTokenRepository.swift
//  FeatureAuth
//
//  Created by 전성훈 on 7/19/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreNetwork
import FeatureAuthInterface
import SharedKit

enum AuthError: Error, Equatable {
    // Secrets.xcconfig 미 설정
    case missingCredentials
    case unableToResolveURL
}

extension AuthError: AppErrorConvertible {
    var asAppError: AppError {
        switch self {
        case .missingCredentials:
            .domain(
                .businessRule(
                    message: "OAuth 키가 설정되지 않았어요. Secrets.xcconfig를 확인해주세요."
                )
            )
        case .unableToResolveURL:
            .common(.message("로그인 주소를 만들지 못했어요."))
        }
    }
}

final class GithubTokenRepository: GithubTokenRepositoryInterface {
    private let session: any NetworkRequesting
    private let credentials: OAuthCredentials?
    
    init(
        session: any NetworkRequesting,
        credentials: OAuthCredentials?
    ) {
        self.session = session
        self.credentials = credentials
    }
    
    func requestAuthorizeURL() throws -> URL {
        guard let credentials else { throw AuthError.missingCredentials }

        var components = URLComponents(
            string: "https://github.com/login/oauth/authorize"
        )
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: credentials.clientID),
            URLQueryItem(name: "scope", value: "user"),
        ]

        guard let url = components?.url else {
            throw AuthError.unableToResolveURL
        }

        return url
    }
    
    func requestAccessToken(with code: String) async throws -> GithubToken {
        guard let credentials else { throw AuthError.missingCredentials }

        let request = GithubAccessTokenRequest(
            clientId: credentials.clientID,
            clientSecret: credentials.clientSecret,
            code: code
        )
        
        return try await session.request(
            GithubAuthAPI.requestAccessToken(request: request),
            type: GithubAccessTokenResponse.self
        ).toDomain()
    }
}
