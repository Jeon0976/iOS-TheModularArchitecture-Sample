//
//  ClearCachedUserUseCase.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

protocol ClearCachedUserUseCase: Sendable {
    func execute()
}

struct ClearCachedUseUseCaseImpl: ClearCachedUserUseCase {
    private let userRepository: any UserRepositoryInterface
    
    init(
        userRepository: any UserRepositoryInterface
    ) {
        self.userRepository = userRepository
    }
    
    func execute() {
        userRepository.clearUser()
    }
}
