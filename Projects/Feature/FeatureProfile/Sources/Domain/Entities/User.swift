//
//  User.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

struct User: Equatable, Sendable {
    let id: Int
    let name: String
    let avatar: Data
    let location: String?
    let followers: Int
    let following: Int
}
