//
//  ProfileViewModel.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation
import Combine

import CoreDesignSystem
import FeatureProfileInterface

struct ProfileViewModelInput: ViewModelInput {
    let viewDidLoadTrigger: AnyPublisher<Void, Never>
    let viewWillAppearTrigger: AnyPublisher<Void, Never>
    let refreshTrigger: AnyPublisher<Void, Never>
    let logoutButtonTapped: AnyPublisher<Void, Never>
}

struct ProfileViewModelOutput: ViewModelOutput {
    let user: AnyPublisher<User, Never>
    let error: AnyPublisher<Error, Never>
    let refreshDidEnd: AnyPublisher<Void, Never>
}

@MainActor
final class ProfileViewModel: BaseViewModel {
    typealias Input = ProfileViewModelInput
    typealias Output = ProfileViewModelOutput
    
    private let fetchUserUseCase: any FetchUserUseCase
    private let refreshUserUseCase: any RefreshUserUseCase
    private let clearCachedUserUseCase: any ClearCachedUserUseCase
    
    private weak let actions: FeatureProfileCoordinatorActions?
    
    var onLogout: (() -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    
    private let fetchTask = ManagedTask()
    
    private let userSubject = PassthroughSubject<User, Never>()
    private let errorSubject = PassthroughSubject<Error, Never>()
    private let refreshDidEndSubject = PassthroughSubject<Void, Never>()
    
    init(
        fetchUserUseCase: any FetchUserUseCase,
        refreshUserUseCase: any RefreshUserUseCase,
        clearCachedUserUseCase: any ClearCachedUserUseCase,
        actions: FeatureProfileCoordinatorActions?
    ) {
        self.fetchUserUseCase = fetchUserUseCase
        self.refreshUserUseCase = refreshUserUseCase
        self.clearCachedUserUseCase = clearCachedUserUseCase
        self.actions = actions
    }
    
    func transform(input: ProfileViewModelInput) -> ProfileViewModelOutput {
        input.viewDidLoadTrigger
            .sink(with: self, in: &cancellables) { owner, _ in
                owner.fetchUser()
            }
        
        input.viewWillAppearTrigger
            .sink(with: self, in: &cancellables) { owner, _ in
                owner.refreshUser(reportsError: false)
            }
        
        input.refreshTrigger
            .sink(with: self, in: &cancellables) { owner, _ in
                owner.refreshUser(reportsError: true)
            }
        
        input.logoutButtonTapped
            .sink(with: self, in: &cancellables) { owner, _ in
                owner.logout()
            }
        
        return Output(
            user: userSubject.eraseToAnyPublisher(),
            error: errorSubject.eraseToAnyPublisher(),
            refreshDidEnd: refreshDidEndSubject.eraseToAnyPublisher()
        )
    }
    
    private func fetchUser() {
        fetchTask.replace(
            with: self,
            onError: { owner, error in
                owner.errorSubject.send(error)
            }
        ) { owner in
            let user = try await owner.fetchUserUseCase.execute()
            
            guard !Task.isCancelled else { return }
            
            owner.userSubject.send(user)
        }
    }
    
    private func refreshUser(reportsError: Bool) {
        guard !fetchTask.isRunning else {
            refreshDidEndSubject.send()
            
            return
        }
        
        fetchTask.runIfIdle(
            with: self,
            onError: { owner, error in
                guard reportsError else { return }
                
                owner.errorSubject.send(error)
            }
        ) { owner in
            // 성공,실패,취소든 스퍼니를 접는다.
            defer { owner.refreshDidEndSubject.send() }
            
            let user = try await owner.refreshUserUseCase.execute()
            
            guard !Task.isCancelled else { return }
            owner.userSubject.send(user)
        }
    }
    
    private func logout() {
        // 1. 토큰 Auth에 위임
        onLogout?()
        // 2. Profile 모듈 캐시 clear
        clearCachedUserUseCase.execute()
        // 3. 화면 전환 - App에 요청
        actions?.profileDidLogout()
    }
}
