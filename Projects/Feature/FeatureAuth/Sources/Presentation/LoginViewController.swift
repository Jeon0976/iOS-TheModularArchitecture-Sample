//
//  LoginViewController.swift
//  FeatureAuth
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit
import Combine

import CoreDesignSystem
import SharedKit

final class LoginViewController: BaseViewController {
    // MARK: - Property
    
    private let viewModel: LoginViewModel
    
    private let loginButtonTapped = PassthroughSubject<Void, Never>()
    
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Component
    
    private let welcomeLabel: UILabel = {
        let label = UILabel()

        label.text = "환영합니다!"
        label.textAlignment = .center
        label.numberOfLines = 1
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    private let loginButton: UIButton = {
        let button = UIButton(type: .system)

        button.setTitle("GitHub로 로그인", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.label, for: .normal)
        button.layer.cornerRadius = 6
        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }()
    
    // MARK: - Initialization
    
    init(viewModel: LoginViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    override func setupLayout() {
        [welcomeLabel, loginButton].forEach {
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            welcomeLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -32),
            welcomeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            loginButton.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 32),
            loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            loginButton.heightAnchor.constraint(equalToConstant: 55),
        ])
    }

    override func setupAttribute() {
        view.backgroundColor = .systemBackground

        loginButton.addTarget(
            self,
            action: #selector(loginButtonTapped(_:)),
            for: .touchUpInside
        )
    }

    // MARK: - Bind
    
    override func bind() {
        let input = LoginViewModelInput(
            loginButtonTapped: loginButtonTapped.eraseToAnyPublisher()
        )

        let output = viewModel.transform(input: input)

        output.authorizeURL
            .sink { url in
                // 승인하면 findusername:// 로 돌아온다
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
            .store(in: &cancellables)

        output.error
            .sink(with: self, in: &cancellables) { owner, error in
                owner.handleError(error)
            }
    }
    
    // MARK: - Error
    
    private func handleError(_ error: Error) {
        if error is CancellationError { return }

        // 키 미설정은 "에러"가 아니라 "설정 방법" 안내
        if case AuthError.missingCredentials = error {
            showAlert(
                title: "OAuth 키가 없어요",
                message:
                """
                Secrets.xcconfig.template을 복사해 Secrets.xcconfig를 만들고
                GitHub OAuth App의 client id/secret을 넣은 뒤 tuist generate 하세요.
                """
            )
            return
        }

        // 나머지는 공통 에러(AppError)
        showAlert(title: "에러", message: AppError.wrap(error).message)
    }
    
    // MARK: - Input
    
    @objc private func loginButtonTapped(_ sender: UIButton) {
        loginButtonTapped.send()
    }
}
