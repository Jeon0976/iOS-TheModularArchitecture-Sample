//
//  UserRepositoryTests.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import XCTest

import CoreNetwork
import CoreNetworkTesting

@testable import FeatureProfile

@MainActor
final class UserRepositoryTests: XCTestCase {
    private func makeResponse() -> UserResponse {
        UserResponse(
            id: 1,
            name: "jeon",
            imagePath: "https://avatars.githubusercontent.com/u/1",
            url: "https://github.com/jeon",
            location: nil,
            followers: 10,
            following: 20
        )
    }
    
    func test_유저와_아바타를_받아_도메인으로_조립한다() async throws {
        let stub = RoutingStubSession(
            userResponse: makeResponse(),
            avatarData: Data([0xCD])
        )
        let storage = UserVolatileStorage()
        let repository = UserRepository(session: stub, userStorage: storage)
        
        let user = try await repository.getUser()
        
        XCTAssertEqual(user.name, "jeon")
        XCTAssertEqual(user.avatar, Data([0xCD]))

        XCTAssertEqual(stub.requestCount, 2, "유저 조회 + 아바타 다운로드")
        XCTAssertEqual(storage.loadUser(), user, "캐시에 저장돼야 한다")
    }
    
    func test_캐시된_유저는_네트워크_없이_반환된다() async throws {
        let stub = StubNetworkRequesting()
        let storage = UserVolatileStorage()
        let cached = User(
            id: 1,
            name: "jeon",
            avatar: Data([0x01]),
            location: "Seoul",
            followers: 1,
            following: 2
        )
        
        storage.saveUser(cached)

        let repository = UserRepository(session: stub, userStorage: storage)

        let user = try await repository.getUser()

        XCTAssertEqual(user, cached)
        XCTAssertTrue(
            stub.requestedEndpoints.isEmpty,
            "캐시 히트면 네트워크가 나가면 안 된다"
        )
    }
    
    func test_refreshUser_성공시_캐시를_덮고_이후_getUser도_새로운_값을_준다() async throws {
        let stub = RoutingStubSession(
            userResponse: UserResponse(
                id: 1,
                name: "jeon",
                imagePath: "https://avatars.githubusercontent.com/u/1",
                url: "https://github.com/jeon",
                location: "Seoul",
                followers: 99,
                following: 20
            ),
            avatarData: Data([0xAB])
        )
        let storage = UserVolatileStorage()
        storage.saveUser(
            User(
                id: 1,
                name: "jeon",
                avatar: Data([0x01]),
                location: "Seoul",
                followers: 1,
                following: 2
            )
        )

        let repository = UserRepository(session: stub, userStorage: storage)

        let refreshed = try await repository.refreshUser()

        XCTAssertEqual(
            refreshed.followers,
            99,
            "서버 값이 돌아와야 한다"
        )
        XCTAssertEqual(
            storage.loadUser()?.followers,
            99,
            "캐시가 새로운 값으로 덮여야 한다"
        )
        XCTAssertEqual(
            storage.loadUser()?.avatar,
            Data([0xAB]),
            "아바타도 새로 받은 것으로"
        )

        let requestsAfterRefresh = stub.requestCount
        let cachedRead = try await repository.getUser()
        XCTAssertEqual(cachedRead.followers, 99)
        XCTAssertEqual(
            stub.requestCount,
            requestsAfterRefresh,
            "getUser는 갱신된 캐시로 답해야 한다"
        )
    }
}

private final class RoutingStubSession: NetworkRequesting, @unchecked Sendable {
    private let userResponse: UserResponse
    private let avatarData: Data
    private(set) var requestCount = 0

    init(userResponse: UserResponse, avatarData: Data) {
        self.userResponse = userResponse
        self.avatarData = avatarData
    }

    func request<T: Decodable & Sendable, E: NetworkEndpoint>(
        _ endpoint: E,
        type: T.Type
    ) async throws -> T {
        requestCount += 1

        guard let typed = userResponse as? T else {
            throw URLError(.cannotDecodeContentData)
        }
        return typed
    }

    func requestWithNoContent<E: NetworkEndpoint>(_ endpoint: E) async throws {
        requestCount += 1
    }

    func requestRawData<E: NetworkEndpoint>(_ endpoint: E) async throws -> Data {
        requestCount += 1
        return avatarData
    }
}
