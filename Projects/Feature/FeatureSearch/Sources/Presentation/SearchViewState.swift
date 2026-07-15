//
//  SearchViewState.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/14/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

enum SearchViewState: Equatable {
    case idle
    case searching
    case loaded(users: [GithubUser], isPagingNext: Bool)
    case empty
}
