//
//  ExchangeGithubTokenUseCase.swift
//  FeatureAuth
//
//  Created by 전성훈 on 7/19/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreStorage

protocol ExchangeGithubTokenUseCase: Sendable {
    func execute(code: String) async throws
}

struct ExchangeGithubTokenUseCaseImpl: ExchangeGithubTokenUseCase {
    private let tokenStorage: any TokenStorage
    private let githubTokenRepository: any GithubTokenRepositoryInterface
    
    init(
        tokenStorage: any TokenStorage,
        githubTokenRepository: any GithubTokenRepositoryInterface
    ) {
        self.tokenStorage = tokenStorage
        self.githubTokenRepository = githubTokenRepository
    }
    
    func execute(code: String) async throws {
        let token = try await githubTokenRepository.requestAccessToken(with: code)
        
        tokenStorage.store(token.token)
    }
}
