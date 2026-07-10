//
//  KeychainTokenStorage.swift
//  CoreStorage
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation
import Security

public final class KeychainTokenStorage: TokenStorage, Sendable {
    private let service: String
    private let account: String
    
    public init(
        service: String = "com.seonghun.gitsearchmicro",
        account: String = "github.access_token"
    ) {
        self.service = service
        self.account = account
    }
    
    public func store(_ token: String) {
        SecItemDelete(baseQuery as CFDictionary)
        
        var query = baseQuery
        
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
#if DEBUG
        if status != errSecSuccess {
            print("[CoreStorage] KeychainTokenStorage.store 실패 — OSStatus \(status)")
        }
#endif
    }
    
    public func retrieve() -> String? {
        var query = baseQuery
        
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    public func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
    
    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

