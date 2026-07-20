//
//  FetchUserUseCase.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

protocol FetchUserUseCase: Sendable {
    func execute() async throws -> User
}

struct FetchUserUseCaseImpl: FetchUserUseCase {
    private let userRepository: any UserRepositoryInterface

    init(userRepository: any UserRepositoryInterface) {
        self.userRepository = userRepository
    }

    func execute() async throws -> User {
        try await userRepository.getUser()
    }
}
