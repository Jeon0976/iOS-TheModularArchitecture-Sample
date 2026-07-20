//
//  UserAPI.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreNetwork

enum UserAPI {
    case getUser
    case downloadAvatar(url: URL)
}

extension UserAPI: NetworkEndpoint {
    var baseURL: URL {
        switch self {
        case .getUser:
            GithubBaseURL.api
        case .downloadAvatar(let url):
            url
        }
    }

    var path: String {
        switch self {
        case .getUser:
            "user"
        case .downloadAvatar:
            ""
        }
    }

    var method: HTTPMethod { .get }

    var task: NetworkTask { .requestPlain }

    var headers: [String: String]? {
        switch self {
        case .getUser:
            ["Accept": "application/vnd.github.v3+json"]
        case .downloadAvatar:
            [:]
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .getUser:
            true
        case .downloadAvatar:
            false
        }
    }
}
