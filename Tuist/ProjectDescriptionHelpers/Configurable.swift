//
//  Configurable.swift
//  Manifests
//
//  Created by 전성훈 on 7/8/26.
//

public protocol Configurable { }

public extension Configurable {
    func with(_ mutate: (inout Self) -> Void) -> Self {
        var copy = self
        
        mutate(&copy)
        
        return copy
    }
}
