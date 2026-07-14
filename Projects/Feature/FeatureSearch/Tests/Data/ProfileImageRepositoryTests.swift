//
//  ProfileImageRepositoryTests.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/14/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import XCTest

import CoreNetworkTesting
import SharedKit

@testable import FeatureSearch

final class ProfileImageRepositoryTests: XCTestCase {
    private let imagePath = "https://avatars.githubusercontent.com/u/1"
    
    func test_캐시에_있으면_네트워크를_타지_않는다() async throws {
        let stub = StubNetworkRequesting()
        let cache = InMemoryProfileCache()
        
        cache.store(Data([0xCA, 0xFE]), forUserID: 1)
        
        let repository = ProfileImageRepository(session: stub, cache: cache)
        
        let data = try await repository.fetchProfile(with: imagePath, userID: 1)
        
        XCTAssertEqual(data, Data([0xCA, 0xFE]))
        XCTAssertTrue(stub.requestedEndpoints.isEmpty, "캐시 히트면 요청이 발생하지 않아야 한다")
    }
    
    func test_캐시에_없으면_다운로드하고_캐시에_저장한다() async throws {
        let stub = StubNetworkRequesting()
        
        stub.result = .success(Data([0x01, 0x02]))
        
        let cache = InMemoryProfileCache()

        let repository = ProfileImageRepository(session: stub, cache: cache)

        let data = try await repository.fetchProfile(with: imagePath, userID: 1)

        XCTAssertEqual(data, Data([0x01, 0x02]))
        XCTAssertEqual(stub.requestedEndpoints.count, 1)
        XCTAssertEqual(
            cache.data(forUserID: 1),
            Data([0x01, 0x02]),
            "다운로드한 건 캐시에 남아야 한다"
        )
    }
    
    func test_두번째_호출은_캐시에서_나온다() async throws {
        let stub = StubNetworkRequesting()
        
        stub.result = .success(Data([0x01]))
        
        let cache = InMemoryProfileCache()

        let repository = ProfileImageRepository(session: stub, cache: cache)

        _ = try await repository.fetchProfile(with: imagePath, userID: 1)
        _ = try await repository.fetchProfile(with: imagePath, userID: 1)

        // 요청 수가 안 늘어난다.
        XCTAssertEqual(stub.requestedEndpoints.count, 1)
    }
}
