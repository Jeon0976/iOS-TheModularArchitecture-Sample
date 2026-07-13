//
//  SearchUserRepositoryInterface.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

protocol SearchUserRepositoryInterface: Sendable {
    func fetchGithubUsers(
        query: GithubUserQuery,
        page: Int,
        perPage: Int
    ) async throws -> GithubUsersPage
}
