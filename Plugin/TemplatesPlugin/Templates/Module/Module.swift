import ProjectDescription


// 사용 방법
// - tuist scaffold Module --name CoreImageLoader --layer Core
// - tuist scaffold Module --name SharedFoo --layer Shared
// layer 는 "Core" 또는 "Shared"
// (대문자 정확히) — ModulePaths.<layer> 로 그대로 쓰인다.
let name: Template.Attribute = .required("name")
let layer: Template.Attribute = .required("layer")

let template = Template(
    description: "new base module (Core/Shared) — implements/testing/tests 3타겟",
    attributes: [name, layer],
    items: [
        .file(
            path: "Projects/\(layer)/\(name)/Project.swift",
            templatePath: "stencils/Project.stencil"
        ),
        .file(
            path: "Projects/\(layer)/\(name)/Sources/\(name).swift",
            templatePath: "stencils/Source.stencil"
        ),
        .file(
            path: "Projects/\(layer)/\(name)/Testing/Sources/\(name)Testing.swift",
            templatePath: "stencils/Testing.stencil"
        ),
        .file(
            path: "Projects/\(layer)/\(name)/Tests/\(name)Tests.swift",
            templatePath: "stencils/Tests.stencil"
        ),
    ]
)
