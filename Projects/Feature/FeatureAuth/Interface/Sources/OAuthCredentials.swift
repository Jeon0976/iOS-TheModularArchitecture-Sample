//
//  OAuthCredentials.swift
//  FeatureAuth
//
//  Created by 전성훈 on 7/16/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

public struct OAuthCredentials: Sendable, Equatable {
    public let clientID: String
    public let clientSecret: String
    
    public init?(clientID: String?, clientSecret: String?) {
        guard let clientID, let clientSecret,
              !clientID.isEmpty, !clientSecret.isEmpty else { return nil }

        self.clientID = clientID
        self.clientSecret = clientSecret
    }
}
