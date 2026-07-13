//
//  FeatureSearchServing.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

@MainActor
public protocol FeatureSearchServing: AnyObject {
    /// 검색 탭의 루트 화면을 만든다.
    /// - Parameter actions: 피처 **밖**으로 나가는 내비게이션(로그인 복귀)의 위임
    ///     피처는 로그인 화면이 어떻게 생겼는지 모른다. / App이 알고 있음
    func makeSearchEntryViewController(actions: FeatureSearchCoordinatorActions?) -> UIViewController
}

@MainActor
public protocol FeatureSearchCoordinatorActions: AnyObject {
    func searchNeedsLogin()
}
