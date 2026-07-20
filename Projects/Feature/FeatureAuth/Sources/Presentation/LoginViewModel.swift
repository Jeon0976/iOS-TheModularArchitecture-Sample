//
//  LoginViewModel.swift
//  FeatureAuth
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation
import Combine

import CoreDesignSystem
import FeatureAuthInterface

struct LoginViewModelInput: ViewModelInput {
    let loginButtonTapped: AnyPublisher<Void, Never>
}

struct LoginViewModelOutput: ViewModelOutput {
    let authorizeURL: AnyPublisher<URL, Never>
    let error: AnyPublisher<Error, Never>
}

@MainActor
final class LoginViewModel: BaseViewModel {
    typealias Inout = LoginViewModelInput
    typealias Output = LoginViewModelOutput
    
    private let requestAuthURLUseCase: any RequestGithubAuthURLUseCase
    private let exchangeTokenUseCase: any ExchangeGithubTokenUseCase
    
    private weak let actions: FeatureAuthCoordinatorActions?
    
    private var cancellables = Set<AnyCancellable>()
    
    private let exchangeTask = ManagedTask()
    
    private let authorizeURLSubject = PassthroughSubject<URL, Never>()
    private let errorSubject = PassthroughSubject<Error, Never>()
    
    init(
        requestAuthURLUseCase: any RequestGithubAuthURLUseCase,
        exchangeTokenUseCase: any ExchangeGithubTokenUseCase,
        actions: FeatureAuthCoordinatorActions?
    ) {
        self.requestAuthURLUseCase = requestAuthURLUseCase
        self.exchangeTokenUseCase = exchangeTokenUseCase
        self.actions = actions
    }
    
    func transform(input: LoginViewModelInput) -> LoginViewModelOutput {
        input.loginButtonTapped
            .sink(with: self, in: &cancellables) { owner, _ in
                owner.requestAuthorization()
            }
        
        return Output(
            authorizeURL: authorizeURLSubject.eraseToAnyPublisher(),
            error: errorSubject.eraseToAnyPublisher()
        )
    }
    
    /// OAuth 콜백으로 받은 Code
    /// AuthServingImpl이 호출한다. 
    func receiveAuthorizationCode(_ code: String) {
        exchangeTask.replace(
            with: self,
            onError: { owner, error in
                owner.errorSubject.send(error)
            }
        ) { owner in
            try await owner.exchangeTokenUseCase.execute(code: code)
            
            guard !Task.isCancelled else { return }
            
            owner.actions?.authDidLogin()
        }
    }
    
    private func requestAuthorization() {
        do {
            let url = try requestAuthURLUseCase.execute()
            
            authorizeURLSubject.send(url)
        } catch {
            errorSubject.send(error)
        }
    }
}
