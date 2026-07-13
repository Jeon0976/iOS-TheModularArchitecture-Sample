//
//  FetchProfileUseCase.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

protocol FeatchProfileUseCase: Sendable {
    func execute(imagePath: String, id: Int) async throws -> Data
}

struct FeatchProfileUseCaseImpl: FeatchProfileUseCase {
    private let profileImageRepository: any ProfileImageRepositoryInterface
    
    init(profileImageRepository: any ProfileImageRepositoryInterface) {
        self.profileImageRepository = profileImageRepository
    }
    
    func execute(imagePath: String, id: Int) async throws -> Data {
        try await profileImageRepository.fetchProfile(with: imagePath, userID: id)
    }
}
