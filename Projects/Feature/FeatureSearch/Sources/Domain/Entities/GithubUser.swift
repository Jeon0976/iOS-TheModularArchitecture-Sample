//
//  GithubUser.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

struct GithubUsersPage: Equatable, Sendable {
    let totalPage: Int
    let currentPage: Int
    let users: [GithubUser]
    
    private static let defaultPerPage: Int = 30
    
    var hasNextPage: Bool {
        totalPage > currentPage
    }
    
    init(
        totalCount: Int,
        currentPage: Int,
        users: [GithubUser]
    ) {
        self.totalPage = Int(ceil(Double(totalCount) / Double(Self.defaultPerPage)))
        self.currentPage = currentPage
        self.users = users
    }
}

struct GithubUser: Equatable, Hashable, Sendable {
    let id: Int
    let name: String
    let profilePath: String
    let url: URL
    
    init(id: Int, name: String, profilePath: String, url: URL) {
        self.id = id
        self.name = name
        self.profilePath = profilePath
        self.url = url
    }
}

struct GithubUserQuery: Sendable {
    let q: String
    
    init(q: String) {
        self.q = q
    }
}
