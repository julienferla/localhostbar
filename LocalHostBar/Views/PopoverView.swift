import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var service: ServerService
    @EnvironmentObject private var updateCheck: UpdateCheckController
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
        .task {
            await updateCheck.performSessionAutoCheckIfNeeded()
        }
        .alert("Mise à jour disponible", isPresented: $updateCheck.showUpdateAlert) {
            Button("Télécharger sur GitHub") {
                updateCheck.openReleaseAndDismiss()
            }
            Button("Plus tard", role: .cancel) {
                updateCheck.remindLater()
            }
        } message: {
            if let u = updateCheck.updateAvailable {
                Text(
                    "La version \(u.version) est disponible sur GitHub. Vous utilisez la version \(GitHubReleaseUpdateChecker.currentAppVersion)."
                )
            }
        }
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
        // MenuBarExtra + .window: ScrollView often gets zero proposed height, so the list
        // vanishes while header/footer still lay out. minHeight reserves space; inner
        // frame(maxWidth: .infinity) helps the scroll content measure correctly.
        ScrollView {
            VStack(spacing: 0) {

                // ── Active servers ────────────────────────────────────────
                // Use VStack (not LazyVStack): LazyVStack can report zero height here.
                if !service.servers.isEmpty {
                    VStack(spacing: 6) {
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
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(minHeight: 260, idealHeight: 360, maxHeight: 460)
        .layoutPriority(1)
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
        VStack(spacing: 0) {
            if let banner = updateCheck.statusBanner {
                updateStatusBanner(banner)
                Divider()
            }
            footerToolbar
        }
    }

    private func updateStatusBanner(_ banner: UpdateStatusBanner) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: banner.kind == .checkFailed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(banner.kind == .checkFailed ? Color.orange : Color.green)
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 8) {
                Text(banner.message)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                Button("OK") {
                    updateCheck.dismissStatusBanner()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
    }

    private var footerToolbar: some View {
        HStack(spacing: 10) {
            // Buy me a beer 🍺
            Text("🍺")
                .font(.system(size: 14))
                .help("Buy me a beer")
                .onTapGesture {
                    NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/julienferla")!)
                }

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

            Button {
                // Defer so the menu bar window does not dismiss with the button action.
                DispatchQueue.main.async {
                    Task { await updateCheck.checkForUpdatesManual() }
                }
            } label: {
                if updateCheck.isChecking {
                    ProgressView()
                        .scaleEffect(0.45)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .help("Vérifier les mises à jour sur GitHub")

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
