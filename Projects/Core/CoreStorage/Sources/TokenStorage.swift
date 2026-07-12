//
//  TokenStorage.swift
//  CoreStorage
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

public protocol TokenStorage: Sendable {
    func store(_ token: String)
    func retrieve() -> String?
    func clear()
}
