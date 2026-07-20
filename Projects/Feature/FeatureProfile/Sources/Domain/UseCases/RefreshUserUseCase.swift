//
//  RefreshUserUseCase.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

protocol RefreshUserUseCase: Sendable {
    func execute() async throws -> User
}

struct RefreshUserUseCaseImpl: RefreshUserUseCase {
    private let userRepository: any UserRepositoryInterface

    init(userRepository: any UserRepositoryInterface) {
        self.userRepository = userRepository
    }

    func execute() async throws -> User {
        try await userRepository.refreshUser()
    }
}
