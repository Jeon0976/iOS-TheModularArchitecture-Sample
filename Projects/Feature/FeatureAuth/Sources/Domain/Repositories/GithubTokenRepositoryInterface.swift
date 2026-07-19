//
//  GithubTokenRepositoryInterface.swift
//  FeatureAuth
//
//  Created by 전성훈 on 7/19/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

protocol GithubTokenRepositoryInterface: Sendable {
    func requestAuthorizeURL() throws -> URL
    func requestAccessToken(with code: String) async throws -> GithubToken
}
