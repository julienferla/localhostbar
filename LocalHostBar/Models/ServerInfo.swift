import Foundation

struct ServerInfo: Identifiable, Equatable {
    var id: String { "\(pid)-\(port)" }

    let port: Int
    let pid: Int
    let command: String
    let workingDirectory: String?
    var project: ProjectInfo?
    var status: ServerStatus

    enum ServerStatus: Equatable {
        case active
        case conflict
    }

    static func == (lhs: ServerInfo, rhs: ServerInfo) -> Bool {
        lhs.pid == rhs.pid && lhs.port == rhs.port && lhs.status == rhs.status
    }
}
