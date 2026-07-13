//
//  ManagedTask.swift
//  CoreDesignSystem
//
//  Created by 전성훈 on 7/12/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

@MainActor
public final class ManagedTask {
    private var task: Task<Void, Never>?
    
    private var generation = 0
    
    public init() {}
    
    deinit {
        task?.cancel()
    }
    
    public var isRunning: Bool { task != nil }
    
    public func replace(
        onError: ((Error) -> Void)? = nil,
        operation: @escaping @MainActor () async throws -> Void
    ) {
        task?.cancel()
        
        start(onError: onError, opeartion: operation)
    }
    
    public func runIfIdle(
        onError: ((Error) -> Void)? = nil,
        operation: @escaping @MainActor () async throws -> Void
    ) {
        guard task == nil else { return }
        
        start(onError: onError, opeartion: operation)
    }
    
    public func cancel() {
        task?.cancel()
        
        task = nil
    }
    
    private func start(
        onError: ((Error) -> Void)?,
        opeartion: @escaping @MainActor () async throws -> Void
    ) {
        generation &+= 1
        
        let startedGeneration = generation
        
        task = Task { [weak self] in
            do {
                try await opeartion()
            } catch is CancellationError {
               // 취소는 실패가 이나리 중단
            } catch {
                // 취소된 작업의 늦은 실패도 침묵
                if !Task.isCancelled { onError?(error) }
            }
            
            if let self, self.generation == startedGeneration {
                self.task = nil
            }
        }
    }
}
