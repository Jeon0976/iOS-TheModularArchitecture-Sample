//
//  MockGithubSearchSession.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/16/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

import CoreNetwork

public final class MockGithubSearchSession: NetworkRequesting, @unchecked Sendable {
    public struct MockUser: Sendable {
        public let id: Int
        public let login: String
        public let htmlURL: String

        public init(id: Int, login: String, htmlURL: String) {
            self.id = id
            self.login = login
            self.htmlURL = htmlURL
        }
    }

    private let database: [MockUser]
    private let perPage: Int
    private let latency: Duration

    /// - Parameters:
    ///   - database: 목 유저 목록. 기본은 아래 sample(편집해서 데모 데이터를 바꾼다).
    ///   - latency: 응답 지연(로딩 상태 관찰용). 0으로 주면 즉시.
    public init(
        database: [MockUser] = MockGithubSearchSession.sample,
        perPage: Int = 30,
        latency: Duration = .milliseconds(500)
    ) {
        self.database = database
        self.perPage = perPage
        self.latency = latency
    }

    // MARK: - NetworkRequesting

    public func request<T: Decodable & Sendable, E: NetworkEndpoint>(
        _ endpoint: E,
        type: T.Type
    ) async throws -> T {
        try? await Task.sleep(for: latency)

        let page = Self.page(from: endpoint)
        let json = try Self.searchResponseJSON(users: pageSlice(page), totalCount: database.count)

        return try JSONDecoder().decode(T.self, from: json)
    }

    public func requestWithNoContent<E: NetworkEndpoint>(_ endpoint: E) async throws {
        try? await Task.sleep(for: latency)
    }

    public func requestRawData<E: NetworkEndpoint>(_ endpoint: E) async throws -> Data {
        try? await Task.sleep(for: latency)

        return Self.avatarPNG(seed: endpoint.baseURL.absoluteString)
    }

    // MARK: - 페이지 슬라이싱

    private func pageSlice(_ page: Int) -> [MockUser] {
        let start = (page - 1) * perPage
        guard start < database.count else { return [] }
        let end = min(start + perPage, database.count)
        return Array(database[start..<end])
    }

    private static func page(from endpoint: some NetworkEndpoint) -> Int {
        if case .requestParameters(let parameters, _) = endpoint.task,
           let raw = parameters["page"],
           let page = Int(raw) {
            return page
        }
        return 1
    }

    // MARK: - JSON 합성 (GitHub /search/users 응답 모양)

    private struct WireUser: Encodable {
        let id: Int
        let login: String
        let html_url: String
        let avatar_url: String
    }

    private struct WirePage: Encodable {
        let total_count: Int
        let items: [WireUser]
    }

    private static func searchResponseJSON(users: [MockUser], totalCount: Int) throws -> Data {
        let items = users.map {
            WireUser(
                id: $0.id,
                login: $0.login,
                html_url: $0.htmlURL,
                // 아바타 URL은 실재하지 않아도 된다 — requestRawData가 색 이미지를 만들어 준다.
                avatar_url: "https://avatars.mock.local/u/\($0.id).png"
            )
        }
        return try JSONEncoder().encode(WirePage(total_count: totalCount, items: items))
    }

    // MARK: - 아바타 생성

    private static let palette: [UIColor] = [
        .systemBlue, .systemGreen, .systemIndigo, .systemOrange,
        .systemPink, .systemPurple, .systemRed, .systemTeal,
    ]

    private static func avatarPNG(seed: String) -> Data {
        let color = palette[abs(seed.hashValue) % palette.count]
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }

    // MARK: - 기본 목 데이터 (편집 지점)

    /// 48명 → perPage 30 기준 2페이지(30 + 18). 무한 스크롤로 2페이지가 실제로 이어붙는다.
    /// 앞 몇은 눈에 익은 이름, 나머지는 생성 — 여기 배열만 고치면 데모 데이터가 바뀐다.
    public static let sample: [MockUser] = {
        let seedLogins = ["octocat", "torvalds", "gaearon", "tenderlove", "mojombo", "defunkt"]
        return (1...48).map { id in
            let login = id <= seedLogins.count ? seedLogins[id - 1] : "github-user-\(id)"
            return MockUser(id: id, login: login, htmlURL: "https://github.com/\(login)")
        }
    }()
}

