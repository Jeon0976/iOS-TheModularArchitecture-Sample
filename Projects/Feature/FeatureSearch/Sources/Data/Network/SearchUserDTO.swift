//
//  SearchUserDTO.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

struct SearchUserRequest: Sendable {
    let query: String
    let page: Int
    let perPage: Int
}

struct SearchUsersResponse: Decodable, Sendable {
    let totalCount: Int
    let users: [SearchUserResponse]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case users = "items"
    }

    func toDomain(currentPage: Int) -> GithubUsersPage {
        GithubUsersPage(
            totalCount: totalCount,
            currentPage: currentPage,
            users: users.map { $0.toDomain() }
        )
    }
}

struct SearchUserResponse: Decodable, Sendable {
    let id: Int
    let name: String
    let url: String
    let imagePath: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "login"
        case url = "html_url"
        case imagePath = "avatar_url"
    }
    
    func toDomain() -> GithubUser {
        let url = URL(string: url) ?? URL(string: "https://github.com")!

        return GithubUser(
            id: id,
            name: name,
            profilePath: imagePath,
            url: url
        )
    }
}
