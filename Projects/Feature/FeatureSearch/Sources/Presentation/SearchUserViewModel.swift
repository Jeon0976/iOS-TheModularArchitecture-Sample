//
//  SearchUserViewModel.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/14/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation
import Combine

import CoreDesignSystem
import FeatureSearchInterface

struct SearchUserViewModelInput: ViewModelInput {
    let searchUser: AnyPublisher<String, Never>
    let loadNextPage: AnyPublisher<Void, Never>
    let backToLogin: AnyPublisher<Void, Never>
}

struct SearchUserViewModelOutput: ViewModelOutput {
    let state: AnyPublisher<SearchViewState, Never>
    let error: AnyPublisher<Error, Never>
}

@MainActor
final class SearchUserViewModel: BaseViewModel {
    typealias Input = SearchUserViewModelInput
    typealias Output = SearchUserViewModelOutput
    
    private let searchUsersUseCase: any SearchUsersUseCase
    private let fetchProfileUseCase: any FetchProfileUseCase
    
    private let paginator = SearchPaginator()
    
    private weak let actions: FeatureSearchCoordinatorActions?
    
    private var cancellables = Set<AnyCancellable>()
    
    private let searchTask = ManagedTask()
    private let loadNextPageTask = ManagedTask()
    
    private let stateSubject = CurrentValueSubject<SearchViewState, Never>(.idle)
    private let errorSubject = PassthroughSubject<Error, Never>()
    
    /// 검색/페이징이 실패했을 때 화면을 되돌릴 상태
    private var lastStableState: SearchViewState = .idle
    
    init(
        searchUsersUseCase: any SearchUsersUseCase,
        fetchProfileUseCase: any FetchProfileUseCase,
        actions: FeatureSearchCoordinatorActions?
    ) {
        self.searchUsersUseCase = searchUsersUseCase
        self.fetchProfileUseCase = fetchProfileUseCase
        self.actions = actions
    }
    
    func transform(
        input: SearchUserViewModelInput
    ) -> SearchUserViewModelOutput {
        input.searchUser
            .filter { !$0.isEmpty }
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                guard let self else { return }
                
                self.searchUsers(query: query)
            }
            .store(in: &cancellables)
        
        input.loadNextPage
            .filter { [weak self] in
                self?.paginator.hasNextPage ?? false
            }
            .sink { [weak self] _ in
                self?.loadNextPage()
            }
            .store(in: &cancellables)
        
        input.backToLogin
            .sink { [weak self] _ in
                self?.actions?.searchNeedsLogin()
            }
            .store(in: &cancellables)
        
        return Output(
            state: stateSubject
                .removeDuplicates()
                .eraseToAnyPublisher(),
            error: errorSubject
                .eraseToAnyPublisher()
        )
    }
    
    func profileData(for user: GithubUser) async throws -> Data {
        try await fetchProfileUseCase.execute(
            imagePath: user.profilePath,
            id: user.id
        )
    }
    
    // MARK: - 상태 전이
    
    
    private func send(_ state: SearchViewState) {
        stateSubject.send(state)
        
        switch state {
        case .idle, .empty:
            lastStableState = state
        case .searching:
            break
        case .loaded(let users, _):
            lastStableState = .loaded(users: users, isPagingNext: false)
        }
    }
    
    private func searchUsers(query: String) {
        loadNextPageTask.cancel()
        
        send(.searching)
        
        searchTask.replace(
            onError: { [weak self] error in
                guard let self else { return }
                
                // 실패 -> 직전에 보던 화면으로 복귀
                self.send(self.lastStableState)
                self.errorSubject.send(error)
            }
        ) { [weak self] in
            guard let self else { return }
            
            let firstPage = paginator.begin(query: query)
            let page = try await searchUsersUseCase.execute(
                query: query,
                page: firstPage,
                perPage: paginator.perPage
            )
            
            guard !Task.isCancelled else { return }
            
            paginator.apply(page)
            
            send(
                page.users.isEmpty ? .empty : .loaded(users: page.users, isPagingNext: false)
            )
        }
    }
    
    private func loadNextPage() {
        guard case .loaded(let users, false) = stateSubject.value else { return }
        
        send(.loaded(users: users, isPagingNext: true))
        
        loadNextPageTask.runIfIdle(
            onError: { [weak self] error in
                guard let self else { return }
                
                self.send(self.lastStableState)
                self.errorSubject.send(error)
            }
        ) { [weak self] in
            guard let self else { return }
            
            let nextPage = try paginator.nextPage()
            let page = try await searchUsersUseCase.execute(
                query: paginator.currentQuery ?? "",
                page: nextPage,
                perPage: paginator.perPage
            )
            
            guard !Task.isCancelled else { return }
            
            paginator.apply(page)
            
            let existingIDs = Set(users.map(\.id))
            let uniqueUsers = page.users.filter {
                !existingIDs.contains($0.id)
            }
            
            send(
                .loaded(
                    users: users + uniqueUsers,
                    isPagingNext: false
                )
            )
        }
    }
}
