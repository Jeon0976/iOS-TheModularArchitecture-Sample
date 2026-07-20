//
//  AppContainer.swift
//  GitSearchApp
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreNetwork
import CoreStorage

import FeatureAuth
import FeatureAuthInterface

import FeatureProfile
import FeatureProfileInterface

import FeatureSearch
import FeatureSearchInterface

@MainActor
final class AppContainer {
    let auth: any FeatureAuthServing
    let search: any FeatureSearchServing
    let profile: any FeatureProfileServing
    
    init() {
        // 1. 인프라
        // 네트워크 파이프라인을 여기서 조립한다.
        // 인터셉터 - 요청을 바꾸는 정책
        // 모니터 - 관찰자
        let tokenStorage = KeychainTokenStorage()
        let session = NetworkSession(
            interceptors: [
                AuthTokenInterceptor(tokenStorage: tokenStorage),
                // 일시적 에러 재시도 - 멱등(GET) 요청
                // OAuth 토큰 교환은 isIdempotent 메서드 유도로 자동 제외
                TransientErrorRetryInterceptor()
            ],
            monitors: [
                NetworkLogger()
            ]
        )
        
        let credentials = OAuthCredentials(
            clientID: Bundle.main.object(forInfoDictionaryKey: "GithubClientID") as? String,
            clientSecret: Bundle.main.object(forInfoDictionaryKey: "GithubClientSecret") as? String
        )
        
        let auth = FeatureAuthServingImpl(
            session: session,
            tokenStorage: tokenStorage,
            credentials: credentials
        )
        
        self.auth = auth
        self.search = FeatureSearchServingImpl(session: session)
        self.profile = FeatureProfileServingImpl(session: session, auth: auth)
    }
}
