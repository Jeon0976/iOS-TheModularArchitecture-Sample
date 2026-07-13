//
//  SearchField.swift
//  CoreDesignSystem
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

public final class SearchField: UITextField {
    private let innerInset: CGFloat = 16
    private let buttonSize: CGFloat = 24
    
    private let rightButton = UIButton()
    
    private let xCircleImage = UIImage(systemName: "x.circle")
    private let searchGlassImage = UIImage(systemName: "magnifyingglass")
    
    private lazy var inset = UIEdgeInsets(
        top: innerInset,
        left: innerInset,
        bottom: innerInset,
        right: innerInset + self.buttonSize + 2
    )
    
    private var _isEditingField: Bool = false
    private var isEditingField: Bool {
        get { _isEditingField }
        set {
            if newValue != _isEditingField {
                let image = newValue ? xCircleImage : searchGlassImage
                
                rightButton.setImage(image, for: .normal)
                
                _isEditingField = newValue
            }
        }
    }
    
    private var rightButtonHidden = false {
        didSet {
            rightView?.isHidden = rightButtonHidden
        }
    }
    
    private var textFieldShouldSearch: (() -> Void)?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        setupAttribute()
        setupRightButton()
        
        observeEvents()
    }
    
    private func applyBorderColor() {
        layer.borderColor = UIColor.label.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 좌우 인셋 적용
    public override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: inset)
    }
    
    public override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: inset)
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #unavailable(iOS 17.0) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {

                applyBorderColor()
            }
        }
    }
    
    private func setupAttribute() {
        self.layer.cornerRadius = 16
        self.layer.borderWidth = 1
        
        applyBorderColor()
        
        self.returnKeyType = .search
    }
    
    private func setupRightButton() {
        rightButton.setImage(searchGlassImage, for: .normal)
        rightButton.tintColor = .label
        rightButton.frame = .init(x: 0, y: 0, width: buttonSize, height: buttonSize)
        
        rightButton.addTarget(
            self,
            action: #selector(rightButtonTapped(_:)),
            for: .touchUpInside
        )
        
        let paddingView = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: buttonSize + innerInset,
                height: buttonSize
            )
        )
        
        paddingView.addSubview(rightButton)
        
        rightView = paddingView
        rightViewMode = .always
    }
    
    private func observeEvents() {
        addTarget(
            self,
            action: #selector(editingStateChanged),
            for: .editingDidBegin
        )
        addTarget(
            self,
            action: #selector(editingStateChanged),
            for: .editingChanged
        )
        addTarget(
            self,
            action: #selector(editingDidFinish),
            for: .editingDidEnd
        )
        
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
                self.applyBorderColor()
            }
        }
    }
    
    @objc private func editingStateChanged() {
        if text?.isEmpty == false {
            rightButtonHidden = false
            isEditingField = true
        } else {
            rightButtonHidden = true
        }
    }
    
    @objc private func editingDidFinish() {
        rightButtonHidden = false
        isEditingField = false
    }
    
    @objc private func rightButtonTapped(_ sender: UIButton) {
        if isEditingField {
            self.rightButtonHidden = true
            self.text = ""
        } else {
            if self.text == "" {
                self.becomeFirstResponder()
            } else {
                self.textFieldShouldSearch?()
            }
        }
    }
}
