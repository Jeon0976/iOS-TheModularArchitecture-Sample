//
//  BaseViewController.swift
//  CoreDesignSystem
//
//  Created by 전성훈 on 7/12/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

@MainActor
open class BaseViewController: UIViewController {
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        setupLayout()
        setupAttribute()
        bind()
    }
    
    open func setupLayout() { }
    open func setupAttribute() { }
    open func bind() { }
}
