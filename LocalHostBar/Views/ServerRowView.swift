import SwiftUI

struct ServerRowView: View {
    let server: ServerInfo
    let onStop: () -> Void
    let onRestart: () -> Void
    @EnvironmentObject private var service: ServerService

    private var path: String? { server.workingDirectory }
    private var pinned: Bool { path.map { service.isPinned($0) } ?? false }
    private var autoRestart: Bool { path.map { service.isAutoRestart($0) } ?? false }
    private var hasLaunchCmd: Bool { server.project?.launchCommand != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                statusDot
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                // Auto-restart toggle (only when a launch command is known)
                if let p = path, hasLaunchCmd {
                    Button {
                        service.toggleAutoRestart(path: p)
                    } label: {
                        Image(systemName: autoRestart
                              ? "arrow.clockwise.circle.fill"
                              : "arrow.clockwise.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(autoRestart ? Color.green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(autoRestart ? "Auto-restart ON — désactiver" : "Auto-restart OFF — activer")
                }
                // Pin button
                if let p = path {
                    Button {
                        service.togglePin(path: p)
                    } label: {
                        Image(systemName: pinned ? "pin.fill" : "pin")
                            .font(.system(size: 11))
                            .foregroundStyle(pinned ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(pinned ? "Désépingler" : "Épingler en tête de liste")
                }
            }

            HStack(spacing: 5) {
                ActionButton(label: "Open", systemImage: "safari") {
                    ProcessManager.openInBrowser(port: server.port)
                }
                if let path = server.workingDirectory {
                    ActionButton(label: "Cursor", systemImage: "cursorarrow.rays") {
                        ProcessManager.openInCursor(path: path)
                    }
                    ActionButton(label: "Terminal", systemImage: "terminal") {
                        ProcessManager.openTerminal(at: path)
                    }
                }
                if server.project?.launchCommand != nil {
                    ActionButton(label: "Restart", systemImage: "arrow.clockwise", action: onRestart)
                }
                ActionButton(label: "Stop", systemImage: "stop.circle", role: .destructive, action: onStop)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(rowBackground)
        .cornerRadius(8)
    }

    // MARK: - Sub-views

    private var statusDot: some View {
        Circle()
            .fill(server.status == .conflict ? Color.orange : Color.green)
            .frame(width: 8, height: 8)
            .padding(.top, 3)
    }

    private var rowBackground: Color {
        server.status == .conflict ? Color.orange.opacity(0.07) : Color.primary.opacity(0.04)
    }

    // MARK: - Computed

    private var title: String {
        if let project = server.project {
            return "\(project.framework.emoji) \(project.name)"
        }
        return server.command
    }

    private var subtitle: String {
        var parts: [String] = []
        if let cmd = server.project?.launchCommand {
            parts.append(cmd)
        }
        parts.append("PID \(server.pid)")
        if server.status == .conflict { parts.append("⚠️ Conflict") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - ActionButton

private struct ActionButton: View {
    let label: String
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(buttonBackground)
            .foregroundStyle(foregroundColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(label)
    }

    private var buttonBackground: Color {
        role == .destructive ? Color.red.opacity(0.10) : Color.primary.opacity(0.07)
    }

    private var foregroundColor: Color {
        role == .destructive ? .red : .primary
    }
}
