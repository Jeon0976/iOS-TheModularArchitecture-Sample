//
//  SearchUsersUseCase.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

protocol SearchUsersUseCase: Sendable {
    func execute(query: String, page: Int, perPage: Int) async throws -> GithubUsersPage
}

struct SearchUsersUseCaseImpl: SearchUsersUseCase {
    private let searchUserRepository: any SearchUserRepositoryInterface
    
    init(searchUserRepository: any SearchUserRepositoryInterface) {
        self.searchUserRepository = searchUserRepository
    }
    
    func execute(
        query: String,
        page: Int,
        perPage: Int
    ) async throws -> GithubUsersPage {
        try await searchUserRepository.fetchGithubUsers(
            query: GithubUserQuery(q: query),
            page: page,
            perPage: perPage
        )
    }
}
