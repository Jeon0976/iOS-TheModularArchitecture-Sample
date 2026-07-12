//
//  KeychainTokenStorageTests.swift
//  CoreStorage
//
//  Created by 전성훈 on 7/12/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import XCTest

import CoreStorage

final class KeychainTokenStorageTests: XCTestCase {
    private var storage: KeychainTokenStorage!
    
    override func setUp() {
        super.setUp()
        storage = KeychainTokenStorage(
            service: "com.seonghun.gitsearchmicro.tests",
            account: "test.token.\(UUID().uuidString)"
        )
    }
    
    override func tearDown() {
        storage.clear()
        storage = nil
        super.tearDown()
    }
    
    func test_저장한_토큰_불러오기() {
        let token = "token"
        
        storage.store(token)
        
        XCTAssertEqual(storage.retrieve(), token)
    }
    
    func test_저장_전에는_nil() {
        XCTAssertNil(storage.retrieve())
    }
    
    func test_덮어쓰면_마지막_토큰만_남는다() {
        storage.store("old")
        storage.store("new")
        XCTAssertEqual(storage.retrieve(), "new")
    }
    
    func test_clear하면_nil로_돌아간다() {
        storage.store("token")
        storage.clear()
        
        XCTAssertNil(storage.retrieve())
    }
}
