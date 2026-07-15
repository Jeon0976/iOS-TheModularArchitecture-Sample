//
//  Publisher+SinkWith.swift
//  CoreDesignSystem
//
//  Created by 전성훈 on 7/15/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Combine

extension Publisher where Failure == Never {
    public func sink<Object: AnyObject>(
        with object: Object,
        receiveValue: @escaping (Object, Self.Output) -> Void
    ) -> AnyCancellable {
        sink { [weak object] output in
            guard let object else { return }
            
            receiveValue(object, output)
        }
    }
    
    public func sink<Object: AnyObject>(
        with object: Object,
        in cancellables: inout Set<AnyCancellable>,
        receiveValue: @escaping (Object, Self.Output) -> Void
    ) {
        sink(with: object, receiveValue: receiveValue)
            .store(in: &cancellables)
    }
}
