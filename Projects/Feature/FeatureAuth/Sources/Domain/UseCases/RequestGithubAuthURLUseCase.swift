//
//  RequestGithubAuthURLUseCase.swift
//  FeatureAuth
//
//  Created by 전성훈 on 7/19/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

protocol RequestGithubAuthURLUseCase: Sendable {
    func execute() throws -> URL
}

struct RequestGithubAuthURLUseCaseImpl: RequestGithubAuthURLUseCase {
    private let githubTokenRepository: any GithubTokenRepositoryInterface
    
    init(githubTokenRepository: any GithubTokenRepositoryInterface) {
        self.githubTokenRepository = githubTokenRepository
    }
    
    func execute() throws -> URL {
        try githubTokenRepository.requestAuthorizeURL()
    }
}
