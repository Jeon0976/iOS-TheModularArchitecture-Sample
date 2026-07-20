//
//  GithubTokenDTO.swift
//  FeatureAuth
//
//  Created by 전성훈 on 7/19/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

struct GithubAccessTokenRequest: Encodable, Sendable {
    let clientId: String
    let clientSecret: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case code
    }
}

struct GithubAccessTokenResponse: Decodable, Sendable {
    let accessToken: String
    let tokenType: String
    let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
    }

    func toDomain() -> GithubToken {
        GithubToken(token: accessToken, tokenType: tokenType)
    }
}
