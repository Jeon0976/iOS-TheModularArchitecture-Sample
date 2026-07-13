//
//  ProfileImageRepositoryInterface.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

protocol ProfileImageRepositoryInterface: Sendable {
    func fetchProfile(with imagePath: String, userID: Int) async throws -> Data
}
