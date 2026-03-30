import SwiftUI

@main
struct LocalHostBarApp: App {
    @StateObject private var serverService = ServerService()
    @StateObject private var updateCheckController = UpdateCheckController()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(serverService)
                .environmentObject(updateCheckController)
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
