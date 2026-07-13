//
//  ManagedTaskTests.swift
//  CoreDesignSystem
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import XCTest

@testable import CoreDesignSystem

@MainActor
final class ManagedTaskTests: XCTestCase {
    func test_replace는_이전_작업을_취소하고_onError를_부르지_않는다() async {
        let managed = ManagedTask()
        
        let firstCancelled = expectation(description: "첫 작업이 CancellationError로 끝난다")
        let secondDone = expectation(description: "두 번째 작업이 실행된다")
        var firstErrorDelivered = false
        
        managed.replace(onError: { _ in firstErrorDelivered = true }) {
            do {
                try await Task.sleep(for: .seconds(10))
                XCTFail("취소되지 않았다")
            } catch {
                XCTAssertTrue(error is CancellationError)
                firstCancelled.fulfill()
                throw error
            }
        }
        
        managed.replace {
            secondDone.fulfill()
        }
        
        await fulfillment(of: [firstCancelled, secondDone], timeout: 2)
        
        // 취소는 실패가 아니다
        XCTAssertFalse(firstErrorDelivered)
        
        // 두 번째 작업이 끝날 때까지 마지막 검증을 미루는 대기 루프
        // fulfillment는 fulfill()이 불린 순간 리턴하는데, fulfill()은 작업 본문
        // 안에 있어서 그 시점엔 마지막 정리 라인(task = nil)이 아직 안 돌았을 수 있다.
        // 그래서 슬롯이 빌 때까지 MainActor를 양보하며 기다린다.
        for _ in 0..<1000 where managed.isRunning { await Task.yield() }
        
        XCTAssertFalse(managed.isRunning)
    }
    
    func test_runIfIdle은_작업이_진행_중이면_새_작업을_시작하지_않는다() async {
        let managed = ManagedTask()
        let firstStarted = expectation(description: "첫번째 작업 시작")
        var gate: CheckedContinuation<Void, Never>?
        
        managed.runIfIdle {
            await withCheckedContinuation { continuation in
                gate = continuation
                
                firstStarted.fulfill()
            }
        }
        
        await fulfillment(of: [firstStarted], timeout: 2)
        
        XCTAssertTrue(managed.isRunning)
        
        var secondRun = false
        managed.runIfIdle { secondRun = true }
        
        gate?.resume()
        
        for _ in 0..<1_000 where managed.isRunning { await Task.yield() }
        
        XCTAssertFalse(secondRun)
        XCTAssertFalse(managed.isRunning)
    }
    
    func test_취소가_아닌_실패는_onError로_전달된다() async {
        struct StubError: Error { }
        
        let managed = ManagedTask()
        let delivered = expectation(description: "onError")
        
        managed.replace(
            onError: { error in
                XCTAssertTrue(error is StubError)
                
                delivered.fulfill()
            }
        ) {
            throw StubError()
        }
        
        await fulfillment(of: [delivered], timeout: 2)
    }
    
    func test_교체된_예전작업의_늦은완료가_진행중인_새작업의_핸들을_지우지_않는다() async {
        let managed = ManagedTask()
        
        var releaseOld: CheckedContinuation<Void, Never>?
        var releaseNew: CheckedContinuation<Void, Never>?
        
        let oldStarted = expectation(description: "예전 작업 시작")
        let newStarted = expectation(description: "새 작업 시작")
        
        managed.replace {
            await withCheckedContinuation { continuation in
                releaseOld = continuation
                oldStarted.fulfill()
            }
        }
        await fulfillment(of: [oldStarted], timeout: 2)
        
        managed.replace {
            await withCheckedContinuation { continuation in
                releaseNew = continuation
                newStarted.fulfill()
            }
        }
        await fulfillment(of: [newStarted], timeout: 2)
        
        
        // 예전 작업을 새 작업이 도는 중에 뒤늦게 완료시킨다.
        
        releaseOld?.resume()
        // 예전 작업의 마지막 정리 라인까지 실행 유도
        for _ in 0..<100 { await Task.yield() }
        
        XCTAssertTrue(
            managed.isRunning,
            "예전 작업의 늦은 완료가 진행 중인 새 작업의 슬롯을 비우면 안 된다"
        )
        
        releaseNew?.resume()
        
        for _ in 0..<1_000 where managed.isRunning { await Task.yield() }
        
        XCTAssertFalse(managed.isRunning)
    }
    
    func test_취소된_작업의_늦은_실패는_onError로_새지_않는다() async {
        struct LateError: Error {}

        let managed = ManagedTask()
        
        var gate: CheckedContinuation<Void, Never>?
        
        let started = expectation(description: "작업 시작")
        let finished = expectation(description: "작업 종료")
        
        var errorDelivered = false

        managed.replace(onError: { _ in errorDelivered = true }) {
            defer { finished.fulfill() }
            
            await withCheckedContinuation { continuation in
                gate = continuation
                started.fulfill()
            }
            
            throw LateError()
        }
        
        await fulfillment(of: [started], timeout: 2)
        
        managed.cancel()
        gate?.resume()
        
        await fulfillment(of: [finished], timeout: 2)
        
        XCTAssertFalse(
            errorDelivered,
            "이미 떠난 화면에 예전 요청의 에러를 알리면 안 된다"
        )
    }
}
