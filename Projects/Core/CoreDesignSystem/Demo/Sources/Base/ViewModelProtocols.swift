//
//  ViewModelProtocols.swift
//  CoreDesignSystem
//
//  Created by 전성훈 on 7/12/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

public protocol ViewModelInput { }
public protocol ViewModelOutput { }

@MainActor
public protocol BaseViewModel {
    associatedtype Input: ViewModelInput
    associatedtype Output: ViewModelOutput
    
    func transform(input: Input) -> Output
}

@MainActor
public protocol CoordinatorActions: AnyObject { }
