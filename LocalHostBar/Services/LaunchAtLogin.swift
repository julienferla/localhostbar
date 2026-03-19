import ServiceManagement

/// Wrapper autour de SMAppService pour gérer le lancement automatique au démarrage.
@MainActor
final class LaunchAtLogin: ObservableObject {

    static let shared = LaunchAtLogin()

    @Published private(set) var isEnabled: Bool = false

    private init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
                isEnabled = false
            } else {
                try SMAppService.mainApp.register()
                isEnabled = true
            }
        } catch {
            print("LaunchAtLogin error:", error.localizedDescription)
        }
    }
}
