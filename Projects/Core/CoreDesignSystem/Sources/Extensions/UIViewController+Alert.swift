//
//  UIViewController+Alert.swift
//  CoreDesignSystem
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

public typealias AlertAction = (
    title: String,
    style: UIAlertAction.Style,
    handler: (() -> Void)?
)

extension UIViewController {
    public func showAlert(
        title: String?,
        message: String?,
        preferredStyle: UIAlertController.Style = .alert,
        actions: [AlertAction] = [("확인", .default, nil)]
    ) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: preferredStyle
        )
        
        for action in actions {
            let actionItem = UIAlertAction(
                title: action.title,
                style: action.style) { _ in
                action.handler?()
            }
            
            alertController.addAction(actionItem)
        }
        
        present(alertController, animated: true)
    }
}
