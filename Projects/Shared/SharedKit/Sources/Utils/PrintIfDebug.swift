//
//  PrintIfDebug.swift
//  SharedKit
//
//  Created by 전성훈 on 7/10/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

public func printIfDebug(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}
