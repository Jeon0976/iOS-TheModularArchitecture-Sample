//
//  SearchUserViewController.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/16/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit
import Combine

import CoreDesignSystem
import SharedKit

final class SearchUserViewController: BaseViewController {
    // MARK: - Property
    
    private let viewModel: SearchUserViewModel
    
    private let searchUser = PassthroughSubject<String, Never>()
    private let loadNextPage = PassthroughSubject<Void, Never>()
    private let backToLogin = PassthroughSubject<Void, Never>()
    
    private var cancellables = Set<AnyCancellable>()
    
    private lazy var profileLoader = CellProfileLoader { [viewModel] user in
        try await viewModel.profileData(for: user)
    }
    
    // MARK: - UI Component
    
    private lazy var searchField: SearchField = {
        let view = SearchField()
        
        view.textColor = .label
        
        return view
    }()
    
    private lazy var usersTableView: UITableView = {
        let tableView = UITableView()
        
        tableView.backgroundColor = .clear
        tableView.isHidden = true
        tableView.delegate = self
        tableView.prefetchDataSource =  self
        tableView.register(
            UserListCell.self,
            forCellReuseIdentifier: UserListCell.identifier
        )
        tableView.separatorStyle = .singleLine
        tableView.rowHeight = UITableView.automaticDimension
        
        return tableView
    }()
    
    // MARK: - Diffable DataSource
    
    private enum Section { case main }
    
    private lazy var dataSource = UITableViewDiffableDataSource<Section, GithubUser>(
        tableView: usersTableView
    ) { [weak self] tableView, indexPath, user in
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: UserListCell.identifier,
            for: indexPath
        ) as? UserListCell else { return UITableViewCell() }
        
        cell.configure(
            name: user.name,
            linkText: user.url.absoluteString
        )
        
        self?.profileLoader.load(user, into: cell)
        
        return cell
    }
    
    private let emptyUserList: UILabel = {
        let label = UILabel()
        
        label.isHidden = true
        label.textColor = .label
        label.text = "EMPTY"
        
        return label
    }()
    
    private let fullLoadingSpinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        
        view.style = .large
        view.startAnimating()
        view.isHidden = true
        view.color = .label
        
        return view
    }()
    
    private var nextPageLoadingSpinner: UIActivityIndicatorView?
    
    // MARK: - Initialization
    init(viewModel: SearchUserViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    override func setupLayout() {
        [
            searchField,
            usersTableView,
            emptyUserList,
            fullLoadingSpinner
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(
                equalTo: self.view.safeAreaLayoutGuide.topAnchor,
                constant: 16
            ),
            searchField.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),

            usersTableView.topAnchor.constraint(equalTo: searchField.bottomAnchor),
            usersTableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            usersTableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            usersTableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            emptyUserList.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            emptyUserList.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),

            fullLoadingSpinner.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            fullLoadingSpinner.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
    }
    
    override func setupAttribute() {
        self.view.backgroundColor = .systemBackground

        searchField.delegate = self
        searchField.textFieldShouldSearch = { [weak self] in
            self?.didSearchUser()
        }
    }
    
    // MARK: - Binding
    
    override func bind() {
        let input = SearchUserViewModelInput(
            searchUser: searchUser.eraseToAnyPublisher(),
            loadNextPage: loadNextPage.eraseToAnyPublisher(),
            backToLogin: backToLogin.eraseToAnyPublisher()
        )
        
        let output = viewModel.transform(input: input)
        
        output.state
            .sink(with: self, in: &cancellables) { owner, state in
                owner.render(state)
            }
        
        output.error
            .sink(with: self, in: &cancellables) { owner, error in
                owner.handleError(error)
            }
    }
    
    // MARK: - Rendering
    
    private func render(_ state: SearchViewState) {
        switch state {
        case .idle:
            fullLoadingSpinner.isHidden = true
            usersTableView.isHidden = true
            emptyUserList.isHidden = true
            
        case .searching:
            fullLoadingSpinner.isHidden = false
            usersTableView.isHidden = true
            emptyUserList.isHidden = true
            
        case .empty:
            fullLoadingSpinner.isHidden = true
            usersTableView.isHidden = true
            emptyUserList.isHidden = false
            
        case .loaded(let users, let isPagingNext):
            fullLoadingSpinner.isHidden = true
            usersTableView.isHidden = false
            emptyUserList.isHidden = true
            
            applySnapshot(users)
            updateNextPageLoading(isPagingNext)
        }
    }
    
    
    private func applySnapshot(_ users: [GithubUser]) {
        let current = dataSource.snapshot().itemIdentifiers
        guard users != current else { return }
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, GithubUser>()
        
        snapshot.appendSections([.main])
        snapshot.appendItems(users)
        
        let isAppend = !current.isEmpty
            && users.count > current.count
            && Array(users.prefix(current.count)) == current

        if isAppend {
            dataSource.apply(snapshot, animatingDifferences: true)
        } else {
            dataSource.applySnapshotUsingReloadData(snapshot)
        }
    }
    
    // MARK: - Loading UI
    
    private func updateNextPageLoading(_ loading: Bool) {
        nextPageLoadingSpinner?.removeFromSuperview()
        
        if loading {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            spinner.color = .black
            spinner.frame = .init(
                origin: .zero,
                size: .init(width: usersTableView.frame.width, height: 50)
            )

            nextPageLoadingSpinner = spinner
            usersTableView.tableFooterView = spinner
        } else {
            usersTableView.tableFooterView = nil
            nextPageLoadingSpinner = nil
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        if error is CancellationError { return }
        
        switch AppError.wrap(error) {
        case .network(.tokenExceeded):
            showAlert(
                title: "에러",
                message: "다시 로그인해주세요.",
                actions: [("확인", .default, { [weak self] in
                    self?.backToLogin.send()
                })]
            )
        case .network(.apiRateLimitExceeded):
            
            showAlert(title: "잠시만요", message: "요청이 많습니다. 잠시 후 다시 시도해주세요.")
        case let wrapped:
            showAlert(title: "에러", message: wrapped.message)
        }
    }
    
    // MARK: - Input
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    private func didSearchUser() {
        guard let query = searchField.text else { return }
        
        searchUser.send(query)
    }
}

// MARK: - UITextFieldDelegate

extension SearchUserViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        didSearchUser()
        
        return true
    }
}

// MARK: - UITableViewDelegate

extension SearchUserViewController: UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        if indexPath.row == dataSource.snapshot().numberOfItems - 5 {
            loadNextPage.send()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let user = dataSource.itemIdentifier(for: indexPath) else { return }
        
        if UIApplication.shared.canOpenURL(user.url) {
            UIApplication.shared.open(user.url)
        }
    }
    
    func tableView(
        _ tableView: UITableView,
        didEndDisplaying cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        guard let cell = cell as? UserListCell,
              let id = cell.representedID
        else { return }
        
        profileLoader.cancelLoad(forID: id)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if searchField.isEditing {
            self.view.endEditing(true)
        }
    }
}

// MARK: - UITableViewDataSourcePrefetching

extension SearchUserViewController: UITableViewDataSourcePrefetching {
    func tableView(
        _ tableView: UITableView,
        prefetchRowsAt indexPaths: [IndexPath]
    ) {
        for indexPath in indexPaths {
            guard let user = dataSource.itemIdentifier(for: indexPath) else { continue }
            
            profileLoader.prefetch(user)
        }
    }
    
    func tableView(
        _ tableView: UITableView,
        cancelPrefetchingForRowsAt indexPaths: [IndexPath]
    ) {
        for indexPath in indexPaths {
            guard let user = dataSource.itemIdentifier(for: indexPath) else { continue }
            
            profileLoader.cancelPrefetch(forID: user.id)
        }
    }
}
