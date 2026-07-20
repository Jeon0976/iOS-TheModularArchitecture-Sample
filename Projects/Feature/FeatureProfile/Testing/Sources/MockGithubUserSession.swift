//
//  MockGithubUserSession.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

import CoreNetwork

public final class MockGithubUserSession: NetworkRequesting, @unchecked Sendable {
    public struct MockProfile: Sendable {
        public let id: Int
        public let login: String
        public let htmlURL: String
        public let location: String?
        public let followers: Int
        public let following: Int
        
        public init(
            id: Int,
            login: String,
            htmlURL: String,
            location: String?,
            followers: Int,
            following: Int
        ) {
            self.id = id
            self.login = login
            self.htmlURL = htmlURL
            self.location = location
            self.followers = followers
            self.following = following
        }
    }
    
    private let profile: MockProfile
    private let latency: Duration
    private let lock = NSLock()
    private var fetchCount = 0
    
    /// - Parameters:
    ///   - profile: 목 프로필. 기본은 아래 sample(편집해서 데모 데이터를 바꾼다).
    ///   - latency: 응답 지연(로딩 관찰용). 0으로 주면 즉시.
    public init(
        profile: MockProfile = MockGithubUserSession.sample,
        latency: Duration = .milliseconds(500)
    ) {
        self.profile = profile
        self.latency = latency
    }
    
    public static let sample = MockProfile(
        id: 976,
        login: "Jeon0976",
        htmlURL: "https://github.com/Jeon0976",
        location: "Seoul, Korea",
        followers: 42,
        following: 17
    )
    
    // MARK: - NetworkRequesting
    
    public func request<T: Decodable & Sendable, E: NetworkEndpoint>(
        _ endpoint: E,
        type: T.Type
    ) async throws -> T {
        try? await Task.sleep(for: latency)
        
        let followersNow = lock.withLock {
            fetchCount += 1
            return profile.followers + (fetchCount - 1)   // 새로고침마다 +1
        }
        
        let json = try Self.userResponseJSON(profile, followers: followersNow)
        return try JSONDecoder().decode(T.self, from: json)
    }
    
    public func requestWithNoContent<E: NetworkEndpoint>(_ endpoint: E) async throws {
        try? await Task.sleep(for: latency)
    }
    
    public func requestRawData<E: NetworkEndpoint>(_ endpoint: E) async throws -> Data {
        try? await Task.sleep(for: latency)
        
        return Self.avatarPNG(seed: endpoint.baseURL.absoluteString)
    }
    
    // MARK: - JSON 합성 (GitHub /user 응답 모양 — UserResponse의 CodingKeys와 일치해야 한다)
    
    private struct WireUser: Encodable {
        let id: Int
        let login: String
        let avatar_url: String
        let html_url: String
        let location: String?
        let followers: Int
        let following: Int
    }
    
    private static func userResponseJSON(_ p: MockProfile, followers: Int) throws -> Data {
        try JSONEncoder().encode(
            WireUser(
                id: p.id,
                login: p.login,
                avatar_url: "https://avatars.mock.local/u/\(p.id).png",
                html_url: p.htmlURL,
                location: p.location,
                followers: followers,
                following: p.following
            )
        )
    }
    
    // MARK: - 아바타 생성
    
    private static let palette: [UIColor] = [
        .systemBlue,
        .systemGreen,
        .systemIndigo,
        .systemOrange,
        .systemTeal,
        .systemPurple,
    ]
    
    private static func avatarPNG(seed: String) -> Data {
        let color = palette[abs(seed.hashValue) % palette.count]
        let size = CGSize(width: 240, height: 240)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }
}
