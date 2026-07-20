//
//  AppFlowCoordinator.swift
//  GitSearchApp
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

import FeatureAuthInterface
import FeatureProfileInterface
import FeatureSearchInterface

@MainActor
final class AppFlowCoordinator {
    private let window: UIWindow
    private let container: AppContainer
    
    init(window: UIWindow, container: AppContainer) {
        self.window = window
        self.container = container
    }
    
    func start() {
        if container.auth.isLoggedIn {
            showMain()
        } else {
            showLogin()
        }
    }
    
    /// OAuth 콜백 URL
    /// SceneDelegate가 전달
    /// 어떤 피처의 URL인지는 피처가 판단
    func handle(_ url: URL) {
        container.auth.handleOAuthCallback(url)
    }
    
    
    // MARK: - 화면 전환 (루트 교체는 App만의 권한)
    
    private func showLogin() {
        let login = container.auth.makeLoginViewController(actions: self)
        
        window.rootViewController = UINavigationController(rootViewController: login)
        window.makeKeyAndVisible()
    }
    
    private func showMain() {
        let searchViewController = container.search.makeSearchEntryViewController(actions: self)
        searchViewController.title = "검색"
        searchViewController.tabBarItem = UITabBarItem(
            title: "검색",
            image: UIImage(systemName: "magnifyingglass"),
            tag: 0
        )

        let profileViewController = container.profile.makeProfileEntryViewController(actions: self)
        profileViewController.title = "프로필"
        profileViewController.tabBarItem = UITabBarItem(
            title: "프로필",
            image: UIImage(systemName: "person.crop.circle"),
            tag: 1
        )
        
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            UINavigationController(rootViewController: searchViewController),
            UINavigationController(rootViewController: profileViewController),
        ]

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }
}

// MARK: - 피처들의 바깥 내비게이션 요청 수신

extension AppFlowCoordinator: FeatureAuthCoordinatorActions {
    func authDidLogin() {
        showMain()
    }
}

extension AppFlowCoordinator: FeatureProfileCoordinatorActions {
    func profileDidLogout() {
        showLogin()
    }
}

extension AppFlowCoordinator: FeatureSearchCoordinatorActions {
    // 토큰 만료
    func searchNeedsLogin() {
        container.auth.logout()
        
        showLogin()
    }
}
