//
//  UserDTO.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

struct UserResponse: Decodable, Sendable {
    let id: Int
    let name: String
    let imagePath: String
    let url: String
    let location: String?
    let followers: Int
    let following: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name = "login"
        case imagePath = "avatar_url"
        case url = "html_url"
        case location
        case followers
        case following
    }

    /// 순수 매핑 — 아바타는 Repository가 받아서 넣어 준다.
    func toDomain(avatar: Data) -> User {
        User(
            id: id,
            name: name,
            avatar: avatar,
            location: location,
            followers: followers,
            following: following
        )
    }
}
