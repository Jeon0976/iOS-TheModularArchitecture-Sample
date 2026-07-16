//
//  SearchUserRepositoryTests.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/14/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import XCTest

import CoreNetworkTesting
import SharedKit

@testable import FeatureSearch

final class SearchUserRepositoryTests: XCTestCase {
    func test_응답_DTO를_엔티티로_전환한다() async throws {
        let stub = StubNetworkRequesting()
        
        stub.result = .success(
            SearchUsersResponse(
                totalCount: 90,
                users: [
                    .init(
                        id: 1,
                        name: "hun",
                        url: "https://github.com/jeon0976",
                        imagePath: "https://avatars.githubusercontent.com/u/1"
                    )
                ]
            )
        )
        
        let repository = SearchUserRepository(session: stub)
        
        let page = try await repository.fetchGithubUsers(query: GithubUserQuery(q: "hun"), page: 1, perPage: 30)
        
    
        XCTAssertEqual(page.totalPage, 3)
        XCTAssertEqual(page.currentPage, 1)
        XCTAssertEqual(page.users.first?.name, "hun")
        XCTAssertTrue(page.hasNextPage)

        // 요청이 실제로 한 번 나갔는지
        XCTAssertEqual(stub.requestedEndpoints.count, 1)
    }
    
    func test_잘못된_html_url은_기본값으로_방어한다() {
         let response = SearchUserResponse(
             id: 1,
             name: "hun",
             url: "",
             imagePath: "https://avatars.githubusercontent.com/u/1"
         )

         XCTAssertEqual(response.toDomain().url.absoluteString, "https://github.com")
     }
    
    
}
