//
//  Feature.swift
//  Plugins
//
//  Created by 전성훈 on 7/8/26.
//

import ProjectDescription

let name: Template.Attribute = .required("name")

let template = Template(
    description: "new micro feature module",
    attributes: [name],
    items: [
        .file(
            path: "Projects/Features/\(name)/Project.swift",
            templatePath: "stencils/Project.stencil"
        ),
        .file(
            path: "Projects/Features/\(name)/Interface/Sources/\(name)Serving.swift",
            templatePath: "stencils/Serving.stencil"
        ),
        .file(
            path: "Projects/Features/\(name)/Sources/Composition/\(name)ServingImpl.swift",
            templatePath: "stencils/ServingImpl.stencil"
        ),
        .file(
            path: "Projects/Features/\(name)/Testing/Sources/Stub\(name)Serving.swift",
            templatePath: "stencils/StubServing.stencil"
        ),
        .file(
            path: "Projects/Features/\(name)/Tests/\(name)Tests.swift",
            templatePath: "stencils/Tests.stencil"
        ),
        .file(
            path: "Projects/Features/\(name)/Demo/Sources/\(name)DemoApp.swift",
            templatePath: "stencils/DemoApp.stencil"
        ),
    ]
)
