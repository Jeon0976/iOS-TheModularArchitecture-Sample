//
//  SceneDelegate.swift
//  GitSearchApp
//
//  Created by 전성훈 on 7/20/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    private var appFlowCoordinator: AppFlowCoordinator?
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        let window = UIWindow(windowScene: windowScene)
        
        let coordinator = AppFlowCoordinator(
            window: window,
            container: AppContainer()
        )
        coordinator.start()
        
        self.appFlowCoordinator = coordinator
        self.window = window
    }
    
    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        guard let url = URLContexts.first?.url else { return }

        appFlowCoordinator?.handle(url)
    }
}
