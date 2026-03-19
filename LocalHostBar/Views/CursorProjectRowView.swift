import SwiftUI

struct CursorProjectRowView: View {
    let project: CursorProject
    @EnvironmentObject private var service: ServerService

    private var pinned: Bool { service.isPinned(project.path) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // ── Header ──────────────────────────────────────────────────
            HStack(spacing: 6) {
                Text(project.framework.emoji)
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(project.framework.rawValue)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Pin button
                Button {
                    service.togglePin(path: project.path)
                } label: {
                    Image(systemName: pinned ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundStyle(pinned ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(pinned ? "Désépingler" : "Épingler en tête de liste")
            }

            // ── Actions ─────────────────────────────────────────────────
            HStack(spacing: 5) {
                // Open in Cursor (focus existing window or open project)
                CursorActionButton(
                    label: "Cursor",
                    systemImage: "cursorarrow.rays"
                ) {
                    ProcessManager.openInCursor(path: project.path)
                }
                .help("Open project in Cursor")

                // Start — always visible; runs detected command or just opens terminal.
                // autoPort=true injects PORT=<free> so a second server doesn't collide.
                let cmd = project.launchCommand
                let rawScript = project.rawLaunchScript
                CursorActionButton(
                    label: "Start",
                    systemImage: "play.fill",
                    tint: .green
                ) {
                    // Pass currently occupied ports so the free-port search skips them instantly.
                    let occupied = Set(service.servers.map(\.port))
                    ProcessManager.openTerminal(
                        at: project.path,
                        command: cmd,
                        rawLaunchScript: rawScript,
                        autoPort: cmd != nil,
                        occupiedPorts: occupied
                    )
                }
                .help(cmd.map { "Run: \($0) (port auto-selected)" } ?? "Open terminal in project")

                // Both — always visible
                CursorActionButton(
                    label: "Both",
                    systemImage: "arrow.triangle.branch",
                    tint: .accentColor
                ) {
                    let occupied = Set(service.servers.map(\.port))
                    ProcessManager.openInCursor(path: project.path)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        ProcessManager.openTerminal(
                            at: project.path,
                            command: cmd,
                            rawLaunchScript: rawScript,
                            autoPort: cmd != nil,
                            occupiedPorts: occupied
                        )
                    }
                }
                .help("Open in Cursor + \(cmd.map { "run: \($0) (port auto)" } ?? "open terminal")")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }
}

// MARK: - CursorActionButton

private struct CursorActionButton: View {
    let label: String
    let systemImage: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(tint.opacity(0.10))
            .foregroundStyle(tint == .primary ? tint : tint)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
