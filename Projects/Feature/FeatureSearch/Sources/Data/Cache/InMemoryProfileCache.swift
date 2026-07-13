//
//  InMemoryProfileCache.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

final class InMemoryProfileCache: ProfileCaching, @unchecked Sendable {
    private let cache = NSCache<NSNumber, NSData>()
    
    init(
        countLimit: Int = 330,
        totalCostLimit: Int = 32 * 1024 * 1024
    ) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }
    
    func data(forUserID id: Int) -> Data? {
        cache.object(forKey: NSNumber(value: id)) as Data?
    }
    
    func store(_ data: Data, forUserID id: Int) {
        cache.setObject(
            data as NSData,
            forKey: NSNumber(value: id),
            cost: data.count
        )
    }
}
