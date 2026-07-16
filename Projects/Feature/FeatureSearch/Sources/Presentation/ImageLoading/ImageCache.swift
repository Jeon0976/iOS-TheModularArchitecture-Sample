//
//  ImageCache.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/15/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

struct CacheStatistics: Equatable {
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0
    
    var lookups: Int { hits + misses }
    var hitRate: Double { lookups == 0 ? 0 : Double(hits) / Double(lookups) }
    
    mutating func recordHit() { hits += 1 }
    mutating func recordMiss() { misses += 1 }
}

final class Cache<Key: Hashable, Value> {
    // NSCache의 AnyObject 요구를 만족시키는 키 박스
    private final class WrappedKey: NSObject {
        let key: Key
        init(_ key: Key) { self.key = key }
        
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            (object as? WrappedKey).map { $0.key == key } ?? false
        }
    }
    
    // 값 박스
    private final class Entry {
        let value: Value
        init(_ value: Value) { self.value = value }
    }
    
    private let storage = NSCache<WrappedKey, Entry>()
    private(set) var statistics = CacheStatistics()
    
    /// - Parameters:
    ///     - countLimit: 최대 항목 수 (0 = 무제한)
    ///     - totalCostLimit: 총 cost 상한 (0 = 무제한)
    init(countLimit: Int = 0, totalCostLimit: Int = 0) {
        storage.countLimit = countLimit
        storage.totalCostLimit = totalCostLimit
    }
    
    func value(forKey key: Key) -> Value? {
        guard let entry = storage.object(forKey: WrappedKey(key)) else {
            statistics.recordMiss()
            
            return nil
        }
        
        statistics.recordHit()
        return entry.value
    }
    
    func insert(_ value: Value, forKey key: Key, cost: Int = 0) {
        storage.setObject(
            Entry(value),
            forKey: WrappedKey(key),
            cost: cost
        )
    }
    
    func removeValue(forKey key: Key) {
        storage.removeObject(forKey: WrappedKey(key))
    }
}
