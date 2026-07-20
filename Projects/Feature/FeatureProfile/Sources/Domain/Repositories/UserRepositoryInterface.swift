//
//  UserRepositoryInterface.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

protocol UserRepositoryInterface: Sendable {
    func getUser() async throws -> User
    func refreshUser() async throws -> User
    func clearUser()
}
