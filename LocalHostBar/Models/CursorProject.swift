import Foundation

struct CursorProject: Identifiable, Equatable {
    let id: UUID
    let path: String
    let name: String
    let framework: ProjectInfo.Framework
    let launchCommand: String?
    /// Raw content of the chosen npm script, e.g. "next dev -p 3000".
    let rawLaunchScript: String?

    init(path: String, name: String, framework: ProjectInfo.Framework, launchCommand: String?, rawLaunchScript: String? = nil) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.framework = framework
        self.launchCommand = launchCommand
        self.rawLaunchScript = rawLaunchScript
    }

    static func == (lhs: CursorProject, rhs: CursorProject) -> Bool {
        lhs.path == rhs.path
    }
}
