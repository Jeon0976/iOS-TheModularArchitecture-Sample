import ProjectDescription

let tuist = Tuist(
    project: .tuist(
        plugins: [
            .local(path: .relativeToRoot("Plugin/EnvironmentPlugin")),
            .local(path: .relativeToRoot("Plugin/DependencyPlugin")),
            .local(path: .relativeToRoot("Plugin/ConfigurationPlugin")),
            .local(path: .relativeToRoot("Plugin/TemplatesPlugin"))
        ],
        generationOptions: .options()
    )
)
