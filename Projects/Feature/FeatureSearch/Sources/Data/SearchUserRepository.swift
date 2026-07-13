//
//  SearchUserRepository.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/14/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreNetwork

final class SearchUserRepository: SearchUserRepositoryInterface {
    private let session: any NetworkRequesting
    
    init(session: any NetworkRequesting) {
        self.session = session
    }
    
    func fetchGithubUsers(
        query: GithubUserQuery,
        page: Int,
        perPage: Int
    ) async throws -> GithubUsersPage {
        let request = SearchUserRequest(
            query: query.q,
            page: page,
            perPage: perPage
        )
        
        return try await session.request(
            SearchUserAPI.requestUsers(request: request),
            type: SearchUsersResponse.self
        ).toDomain(currentPage: page)
    }
}
