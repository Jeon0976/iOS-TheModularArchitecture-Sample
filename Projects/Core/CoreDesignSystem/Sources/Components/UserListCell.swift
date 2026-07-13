//
//  UserListCell.swift
//  CoreDesignSystem
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import UIKit

public final class UserListCell: UITableViewCell {
    public static let identifier = String(describing: UserListCell.self)
    
    public var representedID: Int?
    
    private let imageSize: CGFloat = 55
    
    // MARK: - UI Component
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        
        label.numberOfLines = 1
        label.textColor = .label
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .left
        
        return label
    }()
    
    private let urlLinkLabel: UILabel = {
        let label = UILabel()
        
        label.numberOfLines = 2
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .left
        
        return label
    }()
    
    private lazy var proflileImageView: UIImageView = {
        let imageView = UIImageView()
        
        imageView.layer.cornerRadius = imageSize / 2
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        
        return imageView
    }()
    
    private lazy var profileLoadingSpinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        
        view.style = .medium
        view.color = .label
        view.hidesWhenStopped = true
        
        return view
    }()
    
    // MARK: - Initialization
    
    public override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        setupLayout()
        setupAttribute()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        
        representedID = nil
        proflileImageView.image = nil
        proflileImageView.backgroundColor = .clear
        profileLoadingSpinner.stopAnimating()
        nameLabel.text = ""
        urlLinkLabel.text = ""
    }
    
    // MARK: - Layout
    
    private func setupLayout() {
        [
            nameLabel,
            proflileImageView,
            profileLoadingSpinner,
            urlLinkLabel
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            proflileImageView.leadingAnchor.constraint(
                equalTo: self.contentView.leadingAnchor,
                constant: 8
            ),
            proflileImageView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            proflileImageView.heightAnchor.constraint(equalToConstant: imageSize),
            proflileImageView.widthAnchor.constraint(equalToConstant: imageSize),
            
            profileLoadingSpinner.centerXAnchor.constraint(equalTo: proflileImageView.centerXAnchor),
            profileLoadingSpinner.centerYAnchor.constraint(equalTo: proflileImageView.centerYAnchor),
            
            nameLabel.topAnchor.constraint(
                equalTo: self.contentView.topAnchor,
                constant: 16
            ),
            nameLabel.leadingAnchor.constraint(
                equalTo: proflileImageView.trailingAnchor,
                constant: 6
            ),
            nameLabel.trailingAnchor.constraint(
                equalTo: self.contentView.trailingAnchor,
                constant: -16
            ),
            
            urlLinkLabel.topAnchor.constraint(
                equalTo: nameLabel.bottomAnchor,
                constant: 6
            ),
            urlLinkLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            urlLinkLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            urlLinkLabel.bottomAnchor.constraint(
                equalTo: self.contentView.bottomAnchor,
                constant: -16
            )
        ])
    }
    
    private func setupAttribute() {
        self.backgroundColor = .systemBackground
        self.selectionStyle = .none
    }
    
    // MARK: - Public API
    
    public func configure(name: String, linkText: String) {
        nameLabel.text = name
        urlLinkLabel.text = linkText
    }
    
    public func setProfileLoading() {
        profileLoadingSpinner.startAnimating()
        proflileImageView.image = nil
        proflileImageView.backgroundColor = .clear
    }
    
    private func setProfile(_ image: UIImage?) {
        profileLoadingSpinner.stopAnimating()
        
        if let image {
            proflileImageView.image = image
        } else {
            proflileImageView.backgroundColor = .systemGray4
        }
    }
}
