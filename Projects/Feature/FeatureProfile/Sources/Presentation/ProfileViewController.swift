//
//  ProfileViewController.swift
//  FeatureProfile
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit
import Combine

import CoreDesignSystem
import SharedKit

final class ProfileViewController: BaseViewController {
    // MARK: - Property
    
    private let viewModel: ProfileViewModel
    private let imageSize: CGFloat = 88

    private let viewDidLoadTrigger = PassthroughSubject<Void, Never>()
    private let viewWillAppearTrigger = PassthroughSubject<Void, Never>()
    private let refreshTrigger = PassthroughSubject<Void, Never>()
    private let logoutButtonTapped = PassthroughSubject<Void, Never>()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Component

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()

        scrollView.alwaysBounceVertical = true
        scrollView.refreshControl = refreshControl

        return scrollView
    }()

    private let refreshControl = UIRefreshControl()

    private let nameLabel: UILabel = {
        let label = UILabel()

        label.textAlignment = .center
        label.numberOfLines = 1
        label.font = .systemFont(ofSize: 18, weight: .semibold)

        return label
    }()

    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()

        imageView.layer.cornerRadius = imageSize / 2
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear

        return imageView
    }()

    private let locationLabel: UILabel = {
        let label = UILabel()

        label.textAlignment = .center
        label.numberOfLines = 1
        label.font = .systemFont(ofSize: 14, weight: .medium)

        return label
    }()

    private let followersLabel: UILabel = {
        let label = UILabel()

        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = .systemFont(ofSize: 14, weight: .medium)

        return label
    }()

    private let followingLabel: UILabel = {
        let label = UILabel()

        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = .systemFont(ofSize: 14, weight: .medium)

        return label
    }()

    private let logoutButton: UIButton = {
        let button = UIButton(type: .roundedRect)

        button.setTitle("로그아웃", for: .normal)
        button.backgroundColor = .black
        button.layer.cornerRadius = 6
        button.setTitleColor(.white, for: .normal)

        return button
    }()
    
    // MARK: - Initialization
    
    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        viewWillAppearTrigger.send()
    }
    
    // MARK: - Setup
    
    override func setupLayout() {
        let followStackView = UIStackView()

        followStackView.axis = .horizontal
        followStackView.distribution = .fillEqually
        followStackView.alignment = .center
        followStackView.spacing = 16

        [followersLabel, followingLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            followStackView.addArrangedSubview($0)
        }

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)

        [
            nameLabel,
            avatarImageView,
            locationLabel,
            followStackView,
            logoutButton
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor
            ),

            nameLabel.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor,
                constant: 16
            ),
            nameLabel.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),

            avatarImageView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 32),
            avatarImageView.heightAnchor.constraint(equalToConstant: imageSize),
            avatarImageView.widthAnchor.constraint(equalToConstant: imageSize),
            avatarImageView.centerXAnchor.constraint(equalTo: nameLabel.centerXAnchor),

            locationLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 16),
            locationLabel.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),

            followStackView.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 16),
            followStackView.centerXAnchor.constraint(equalTo: locationLabel.centerXAnchor),

            logoutButton.topAnchor.constraint(equalTo: followStackView.bottomAnchor, constant: 16),
            logoutButton.centerXAnchor.constraint(equalTo: followStackView.centerXAnchor),
            logoutButton.widthAnchor.constraint(equalToConstant: 120),
            logoutButton.heightAnchor.constraint(equalToConstant: 56),

            logoutButton.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                constant: -16
            )
        ])
    }
    
    override func setupAttribute() {
        self.view.backgroundColor = .systemBackground

        logoutButton.addTarget(
            self,
            action: #selector(logoutButtonTapped(_:)),
            for: .touchUpInside
        )
        refreshControl.addTarget(
            self,
            action: #selector(refreshPulled(_:)),
            for: .valueChanged
        )
    }
    
    // MARK: - Bind
    
    override func bind() {
        let input = ProfileViewModelInput(
            viewDidLoadTrigger: viewDidLoadTrigger.eraseToAnyPublisher(),
            viewWillAppearTrigger: viewWillAppearTrigger.eraseToAnyPublisher(),
            refreshTrigger: refreshTrigger.eraseToAnyPublisher(),
            logoutButtonTapped: logoutButtonTapped.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.user
            .sink(with: self, in: &cancellables) { owner, user in
                owner.render(user)
            }

        output.error
            .sink(with: self, in: &cancellables) { owner, error in
                owner.showAlert(
                    title: "에러",
                    message: AppError.wrap(error).message
                )
            }

        output.refreshDidEnd
            .sink(with: self, in: &cancellables) { owner, _ in
                owner.refreshControl.endRefreshing()
            }

        viewDidLoadTrigger.send()
    }
    
    private func render(_ user: User) {
        nameLabel.text = user.name
        avatarImageView.image = UIImage(data: user.avatar)
        locationLabel.text = user.location ?? "-"
        followersLabel.text = "Followers: \(user.followers)"
        followingLabel.text = "Following: \(user.following)"
    }
    
    // MARK: - Input
    
    @objc private func logoutButtonTapped(_ sender: UIButton) {
        logoutButtonTapped.send()
    }

    @objc private func refreshPulled(_ sender: UIRefreshControl) {
        refreshTrigger.send()
    }
}
