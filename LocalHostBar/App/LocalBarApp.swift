import SwiftUI

@main
struct LocalHostBarApp: App {
    @StateObject private var serverService = ServerService()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(serverService)
        } label: {
            // Dynamic icon: green dot when at least one server is active
            if serverService.servers.isEmpty {
                Image(systemName: "server.rack")
            } else {
                Image(systemName: "server.rack")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.green, .primary)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
