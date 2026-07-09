//
//  SourceFiles+Template.swift
//  Manifests
//
//  Created by 전성훈 on 7/8/26.
//

import ProjectDescription

public extension SourceFilesList {
    static var interface: SourceFilesList { "Interface/Sources/**" }
    static var implementation: SourceFilesList { "Sources/**" }
    static var testing: SourceFilesList { "Testing/Sources/**" }
    static var unitTests: SourceFilesList { "Tests/**" }
    static var demo: SourceFilesList { "Demo/Sources/**" }
}
