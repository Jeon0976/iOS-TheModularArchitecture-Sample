//
//  ReadStoredTokenUseCase.swift
//  FeatureAuth
//
//  Created by 전성훈 on 7/19/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import CoreStorage

protocol ReadStoredTokenUseCase: Sendable {
    func execute() -> String?
}

struct ReadStoredTokenUseCaseImpl: ReadStoredTokenUseCase {
    private let tokenStorage: any TokenStorage
    
    init(tokenStorage: any TokenStorage) {
        self.tokenStorage = tokenStorage
    }
    
    func execute() -> String? {
        tokenStorage.retrieve()
    }
}
