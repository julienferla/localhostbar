import Foundation

struct RecentServer: Codable, Identifiable, Equatable {
    let id: UUID
    let port: Int
    let name: String
    let framework: String
    var lastSeen: Date

    init(id: UUID = UUID(), port: Int, name: String, framework: String, lastSeen: Date = Date()) {
        self.id = id
        self.port = port
        self.name = name
        self.framework = framework
        self.lastSeen = lastSeen
    }
}
