//
//  SearchUserAPI.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreNetwork

enum SearchUserAPI {
    case requestUsers(request: SearchUserRequest)
    case downloadImage(url: URL)
}

extension SearchUserAPI: NetworkEndpoint {
    var baseURL: URL {
        switch self {
        case .requestUsers:
            GithubBaseURL.api
        case .downloadImage(let url):
            url
        }
    }
    
    var path: String {
        switch self {
        case .requestUsers:
            "search/users"
        case .downloadImage:
            ""
        }
    }
    
    var method: CoreNetwork.HTTPMethod { .get }
    
    var task: CoreNetwork.NetworkTask {
        switch self {
        case .requestUsers(let request):
            .requestParameters(
                parameters: [
                    "q": request.query,
                    "page": String(request.page),
                    "per_page": String(request.perPage),
                ],
                encoding: URLEncoding.queryString
            )
        case .downloadImage:
            .requestPlain
        }
    }
    
    var headers: [String: String]? {
        switch self {
        case .requestUsers:
            ["Accept": "application/vnd.github.v3+json"]
        case .downloadImage:
            [:]
        }
    }
    
    var requiresAuth: Bool {
        switch self {
        case .requestUsers:
            true
        case .downloadImage:
            false
        }
    }
}
