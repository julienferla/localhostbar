import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var service: ServerService
    @StateObject private var launchAtLogin = LaunchAtLogin.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 340)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Label("LocalHostBar", systemImage: "server.rack")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if service.isScanning {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Active servers ────────────────────────────────────────
                if !service.servers.isEmpty {
                    LazyVStack(spacing: 6) {
                        ForEach(service.servers) { server in
                            ServerRowView(server: server,
                                          onStop: { service.stop(server: server) },
                                          onRestart: { service.restart(server: server) })
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // ── Cursor projects without a running server ──────────────
                if !service.cursorProjects.isEmpty {
                    if !service.servers.isEmpty { Divider() }
                    cursorProjectsSection
                }

                // ── Empty state ───────────────────────────────────────────
                if service.servers.isEmpty && service.cursorProjects.isEmpty {
                    emptyMessage
                    if !service.recentServers.isEmpty {
                        Divider()
                        historySection
                    }
                }
            }
        }
        .frame(maxHeight: 460)
    }

    private var emptyMessage: some View {
        VStack(spacing: 10) {
            Image(systemName: "network.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No servers detected")
                .font(.system(size: 13, weight: .medium))
            Text("Start a dev server to see it here.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var cursorProjectsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "cursorarrow.rays")
                    .font(.system(size: 10))
                Text("Cursor Projects")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 10)

            ForEach(service.cursorProjects) { project in
                CursorProjectRowView(project: project)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.bottom, 10)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            ForEach(service.recentServers.prefix(5)) { recent in
                HStack(spacing: 8) {
                    Text(recent.framework)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .leading)
                    Text(recent.name)
                        .font(.system(size: 12))
                    Spacer()
                    Text(String(format: ":%d", recent.port))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
            }
        }
        .padding(.bottom, 8)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            // Buy me a beer 🍺
            Button {
                NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/julienferla")!)
            } label: {
                Text("🍺")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help("Buy me a beer")

            Text("\(service.servers.count) server\(service.servers.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            // Launch at login toggle
            Button {
                launchAtLogin.toggle()
            } label: {
                Image(systemName: launchAtLogin.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(launchAtLogin.isEnabled ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(launchAtLogin.isEnabled ? "Désactiver le lancement au démarrage" : "Lancer au démarrage")

            Text("Startup")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .onTapGesture { launchAtLogin.toggle() }

            Button("Refresh") {
                Task { await service.refresh() }
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
