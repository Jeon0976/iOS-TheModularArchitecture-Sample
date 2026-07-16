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
            .sink(with: self, in: &cancellables) { owner, query in
                owner.searchUsers(query: query)
            }
        
        input.loadNextPage
            .filter { [weak self] in
                self?.paginator.hasNextPage ?? false
            }
            .sink(with: self, in: &cancellables) { owner, _ in
                owner.loadNextPage()
            }

        input.backToLogin
            .sink(with: self, in: &cancellables) { owner, _ in
                owner.actions?.searchNeedsLogin()
            }
        
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
            with: self,
            onError: { owner, error in
                // 실패 -> 직전에 보던 화면으로 복귀
                owner.send(owner.lastStableState)
                owner.errorSubject.send(error)
            }
        ) { owner in
            let firstPage = owner.paginator.begin(query: query)
            
            let page = try await owner.searchUsersUseCase.execute(
                query: query,
                page: firstPage,
                perPage: owner.paginator.perPage
            )

            guard !Task.isCancelled else { return }

            owner.paginator.apply(page)
            owner.send(page.users.isEmpty ? .empty : .loaded(users: page.users, isPagingNext: false))
        }
    }
    
    private func loadNextPage() {
        guard case .loaded(let users, false) = stateSubject.value else { return }
        
        send(.loaded(users: users, isPagingNext: true))
        
        loadNextPageTask.runIfIdle(
            with: self,
            onError: { owner, error in
                owner.send(owner.lastStableState)
                owner.errorSubject.send(error)
            }
        ) { owner in
            let nextPage = try owner.paginator.nextPage()
            let page = try await owner.searchUsersUseCase.execute(
                query: owner.paginator.currentQuery ?? "",
                page: nextPage,
                perPage: owner.paginator.perPage
            )

            guard !Task.isCancelled else { return }

            owner.paginator.apply(page)

            // 서버가 페이지 경계에서 같은 사용자를 중복으로 줄 수 있다 — id로 방어.
            let existingIDs = Set(users.map(\.id))
            let uniqueUsers = page.users.filter { !existingIDs.contains($0.id) }

            owner.send(.loaded(users: users + uniqueUsers, isPagingNext: false))
        }
    }
}
