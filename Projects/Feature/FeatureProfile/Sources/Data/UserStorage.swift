//
//  UserStorage.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

protocol UserStorageInterface: Sendable {
    func saveUser(_ user: User)
    func loadUser() -> User?
    func clearUser()
}

final class UserVolatileStorage: UserStorageInterface, @unchecked Sendable {
    private let lock = NSLock()
    private var user: User?
    
    func saveUser(_ user: User) {
        lock.lock(); defer { lock.unlock() }
        self.user = user
    }
    
    func loadUser() -> User? {
        lock.lock(); defer { lock.unlock() }
        return user
    }

    func clearUser() {
        lock.lock(); defer { lock.unlock() }
        user = nil
    }

}
