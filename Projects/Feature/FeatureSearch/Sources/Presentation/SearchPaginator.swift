//
//  SearchPaginator.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/14/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

import SharedKit

@MainActor
final class SearchPaginator {
    private(set) var currentQuery: String?
    private(set) var currentPage: Int = 1
    private(set) var totalPages: Int = 0
    private(set) var hasNextPage: Bool = false
    
    let perPage: Int = 30
    
    func begin(query: String) -> Int {
        reset()
        
        currentQuery = query
        
        return currentPage
    }
    
    func nextPage() throws -> Int {
        guard currentQuery != nil else {
            throw DomainError.validation(message: "검색어를 입력해주세요.")
        }
        
        return currentPage + 1
    }
    
    func apply(_ page: GithubUsersPage) {
        currentPage = page.currentPage
        totalPages = page.totalPage
        hasNextPage = page.hasNextPage
    }
    
    func reset() {
        currentQuery = nil
        currentPage = 1
        totalPages = 0
        hasNextPage = false
    }
}
