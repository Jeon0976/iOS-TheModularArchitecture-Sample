//
//  StorageDemoApp.swift
//  CoreStorage
//
//  Created by 전성훈 on 7/12/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

import CoreStorage

@main
final class StorageDemoAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = StorageDemoViewController()
        window.makeKeyAndVisible()

        self.window = window
        return true
    }
}

final class StorageDemoViewController: UIViewController {
    private let storage = KeychainTokenStorage(account: "demo.storage.token")
    
    private let stateLabel: UILabel = {
        let label = UILabel()
        
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupLayout()
        render()
    }
    
    private func setupLayout() {
        let store = button("store (\"demo-\" + 시각)") { [weak self] in
            self?.storage.store("demo-\(Int(Date().timeIntervalSince1970) % 100000)")
            self?.render()
        }
        
        let clear = button("clear") { [weak self] in
            self?.storage.clear()
            self?.render()
        }
        
        let refresh = button("retrieve (다시 읽기)") { [weak self] in
            self?.render()
        }
        
        let stack = UIStackView(
            arrangedSubviews: [
                stateLabel,
                store,
                refresh,
                clear
            ]
        )
        
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private func render() {
        let token = storage.retrieve()
        
        stateLabel.text = token.map { "저장된 토큰:\n\($0)" }  ?? "저장된 토큰 없음 (nil)"
        
        stateLabel.textColor = token == nil ? .secondaryLabel : .label
    }
    
    private func button(
        _ title: String,
        action: @escaping () -> Void
    ) -> UIButton {
        var config = UIButton.Configuration.plain()
        
        config.title = title
        
        return UIButton(
            configuration: config,
            primaryAction: UIAction { _ in action() }
        )
    }
}
