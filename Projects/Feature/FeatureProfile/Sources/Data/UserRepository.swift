//
//  UserRepository.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreNetwork
import SharedKit

final class UserRepository: UserRepositoryInterface {
    private let session: any NetworkRequesting
    private let userStorage: any UserStorageInterface
    
    init(
        session: any NetworkRequesting,
        userStorage: any UserStorageInterface
    ) {
        self.session = session
        self.userStorage = userStorage
    }
    
    func getUser() async throws -> User {
        if let cachedUser = userStorage.loadUser() {
            return cachedUser
        }
        
        return try await refreshUser()
    }
    
    func refreshUser() async throws -> User {
        let response = try await session.request(
            UserAPI.getUser,
            type: UserResponse.self
        )
        
        guard let avatarURL = URL(string: response.imagePath) else {
            throw NetworkError.invalidURL
        }
        
        let avatar = try await session.requestRawData(UserAPI.downloadAvatar(url: avatarURL))
        
        let user = response.toDomain(avatar: avatar)
        
        userStorage.saveUser(user)
        
        return user
    }
    
    func clearUser() {
        userStorage.clearUser()
    }
}
