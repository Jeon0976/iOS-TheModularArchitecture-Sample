//
//  ProfileImageRepository.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/14/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreNetwork
import SharedKit

final class ProfileImageRepository: ProfileImageRepositoryInterface {
    private let session: any NetworkRequesting
    private let cache: any ProfileCaching
    
    init(session: any NetworkRequesting, cache: any ProfileCaching) {
        self.session = session
        self.cache = cache
    }
    
    func fetchProfile(
        with imagePath: String,
        userID: Int
    ) async throws -> Data {
        if let cache = cache.data(forUserID: userID) { return cache }
        
        guard let url = URL(string: imagePath) else {
            throw NetworkError.invalidURL
        }
        
        let data = try await session.requestRawData(
            SearchUserAPI.downloadImage(url: url)
        )
        
        cache.store(data, forUserID: userID)
        
        return data
    }
}
