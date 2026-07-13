//
//  ComponentUserListViewController.swift
//  CoreDesignSystem
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

import CoreDesignSystem

final class ComponentUserListViewController: BaseViewController {
    private let searchField = SearchField()
    private let tableView = UITableView()
    
    private struct UserRow: Hashable {
        enum ProfileState: Hashable { case loading, success, failure }
        
        let state: ProfileState
        let name: String
        let link: String
    }
    
    private enum Section { case main }
    
    private let rows: [UserRow] = [
        .init(state: .loading, name: "로딩 중...", link: "..."),
        .init(state: .success, name: "성공", link: "..."),
        .init(state: .failure, name: "실패", link: "...")
    ]
    
    private lazy var dataSource = UITableViewDiffableDataSource<Section, UserRow>(tableView: tableView) { tableView, indexPath, row in
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: UserListCell.identifier, for: indexPath
        ) as? UserListCell else { return UITableViewCell() }
        
        cell.configure(name: row.name, linkText: row.link)
        
        switch row.state {
        case .loading:
            cell.setProfileLoading()
        case .success:
            cell.setProfile(UIImage(systemName: "person.crop.circle.fill"))
        case .failure:
            cell.setProfile(nil)
        }
        
        return cell
    }
    
    override func setupLayout() {
        [
            searchField,
            tableView
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchField.heightAnchor.constraint(equalToConstant: 56),

            tableView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    override func setupAttribute() {
        title = "CoreDesignSystem 갤러리"
        view.backgroundColor = .systemBackground
        
        searchField.placeholder = "SearchField — 돋보기를 눌러보세요"
        searchField.textFieldShouldSearch = { [weak self] in
            self?.showAlert("textFieldShouldSearch 클로저 호출됨")
        }

        tableView.register(
            UserListCell.self,
            forCellReuseIdentifier: UserListCell.identifier
        )

        var snapshot = NSDiffableDataSourceSnapshot<Section, UserRow>()
        snapshot.appendSections([.main])
        snapshot.appendItems(rows)
        
        dataSource.applySnapshotUsingReloadData(snapshot)
    }
    
    private func showAlert(_ message: String) {
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(.init(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
}
