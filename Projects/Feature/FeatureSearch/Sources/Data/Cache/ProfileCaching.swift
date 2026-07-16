//
//  ProfileCaching.swift
//  FeatureSearch
//
//  Created by 전성훈 on 7/13/26.
//  Copyright © 2026 com.seonghun.gitsearchmicro. All rights reserved.
//

import Foundation

protocol ProfileCaching: Sendable {
    func data(forUserID id: Int) -> Data?
    func store(_ data: Data, forUserID id: Int)
}
