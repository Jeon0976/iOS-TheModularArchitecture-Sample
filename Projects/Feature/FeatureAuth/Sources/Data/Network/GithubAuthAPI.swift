//
//  GithubAuthAPI.swift
//  FeatureAuth
//
//  Created by 전성훈 on 7/19/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreNetwork

enum GithubAuthAPI {
    case requestAccessToken(request: GithubAccessTokenRequest)
}

extension GithubAuthAPI: NetworkEndpoint {
    var baseURL: URL {
        GithubBaseURL.auth
    }

    var path: String {
        switch self {
        case .requestAccessToken:
            "login/oauth/access_token"
        }
    }

    var method: HTTPMethod { .post }

    var task: NetworkTask {
        switch self {
        case .requestAccessToken(let request):
            .requestJSONEncodable(request)
        }
    }

    var headers: [String: String]? {
        [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
    }

    var requiresAuth: Bool { false }
}
