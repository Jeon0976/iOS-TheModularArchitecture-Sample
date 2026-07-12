//
//  MockTokenStorage.swift
//  CoreStorage
//
//  Created by 전성훈 on 7/11/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import CoreStorage

public final class MockTokenStorage: TokenStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?
    
    public init(token: String? = nil) {
        self.token = token
    }
    
    public func store(_ token: String) {
        lock.lock()
        
        defer { lock.unlock() }
        
        self.token = token
    }
    
    public func retrieve() -> String? {
        lock.lock()
        
        defer { lock.unlock() }
        
        return token
    }
    
    public func clear() {
        lock.lock()
        
        defer { lock.unlock() }
        
        token = nil
    }
}
