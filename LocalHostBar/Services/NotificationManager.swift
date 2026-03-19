import UserNotifications

enum NotificationManager {

    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func serverStarted(name: String, port: Int) {
        send(
            title: "🟢 Server started",
            body: "\(name) is now running on port \(port)"
        )
    }

    static func serverStopped(name: String, port: Int) {
        send(
            title: "🔴 Server stopped",
            body: "\(name) on port \(port) is no longer running"
        )
    }

    // MARK: - Private

    private static func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
