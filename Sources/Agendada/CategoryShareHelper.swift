import AgendadaCore

enum CategoryShareHelper {
    static func shareText(for category: ProjectCategory, projects: [Project]) -> String {
        let activeProjects = projects.filter { $0.categoryID == category.id && !$0.isArchived }
        var lines = [
            category.name,
            "共 \(activeProjects.count) 个项目",
            ""
        ]
        for project in activeProjects {
            lines.append("- \(project.name)")
        }
        return lines.joined(separator: "\n")
    }
}
