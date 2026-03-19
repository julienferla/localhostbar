import Foundation
import Combine

@MainActor
final class ServerService: ObservableObject {
    @Published private(set) var servers: [ServerInfo] = []
    @Published private(set) var recentServers: [RecentServer] = []
    @Published private(set) var cursorProjects: [CursorProject] = []
    @Published private(set) var isScanning = false
    @Published private(set) var pinnedPaths: Set<String> = []

    private var timer: DispatchSourceTimer?
    private let scanQueue = DispatchQueue(label: "com.localhostbar.scanner", qos: .utility)

    /// PIDs seen in the previous scan cycle — used to diff starts/stops for notifications.
    private var previousPIDs: Set<Int> = []

    private let historyKey  = "com.localhostbar.recentServers"
    private let pinnedKey   = "com.localhostbar.pinnedPaths"

    init() {
        loadHistory()
        loadPinned()
        NotificationManager.requestAuthorization()
        startPolling()
    }

    deinit {
        timer?.cancel()
    }

    // MARK: - Public actions

    func stop(server: ServerInfo) {
        // Optimistic UI: remove immediately for instant feedback
        servers.removeAll { $0.id == server.id }

        ProcessManager.stop(pid: server.pid)

        // Confirm state after process has had time to die
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 s
            await refresh()
        }
    }

    // MARK: - Pin

    func togglePin(path: String) {
        if pinnedPaths.contains(path) {
            pinnedPaths.remove(path)
        } else {
            pinnedPaths.insert(path)
        }
        savePinned()
        // Re-sort immediately so the UI reacts without waiting for the next scan
        servers        = sorted(servers)
        cursorProjects = sorted(cursorProjects)
    }

    func isPinned(_ path: String) -> Bool { pinnedPaths.contains(path) }

    func restart(server: ServerInfo) {
        let occupied = Set(servers.map(\.port))
        ProcessManager.restart(server: server, occupiedPorts: occupied)
        // The polling cycle will pick up the new process automatically
    }

    func refresh() async {
        await performScan()
    }

    // MARK: - Polling

    private func startPolling() {
        let t = DispatchSource.makeTimerSource(queue: scanQueue)
        t.schedule(deadline: .now(), repeating: 3.0)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.performScan() }
        }
        t.resume()
        timer = t
    }

    // MARK: - Scan

    private func performScan() async {
        let (results, detectedCursorProjects): ([ServerInfo], [CursorProject]) = await Task.detached(priority: .utility) {
            let rawEntries = PortScanner.scan()
            var infos: [ServerInfo] = []

            for entry in rawEntries {
                let cwd = PortScanner.workingDirectory(for: entry.pid)
                let project = cwd.map { ProjectDetector.detect(at: $0) }

                let info = ServerInfo(
                    port: entry.port,
                    pid: entry.pid,
                    command: entry.command,
                    workingDirectory: cwd,
                    project: project,
                    status: .active
                )
                infos.append(info)
            }

            // Mark conflicts (same port, multiple PIDs — defensive)
            let portCounts = Dictionary(grouping: infos, by: \.port)
            let processedInfos = infos.map { info -> ServerInfo in
                var copy = info
                if (portCounts[info.port]?.count ?? 0) > 1 { copy.status = .conflict }
                return copy
            }

            // Cursor projects that don't already have a running server
            let activePaths = Set(processedInfos.compactMap(\.workingDirectory))
            let cursorProjects = CursorDetector.openProjects()
                .filter { !activePaths.contains($0.path) }

            return (processedInfos, cursorProjects)
        }.value

        // ── Diff for notifications ───────────────────────────────────────
        let newPIDs   = Set(results.map(\.pid))
        let started   = results.filter { !previousPIDs.contains($0.pid) }
        let stoppedPIDs = previousPIDs.subtracting(newPIDs)

        for server in started {
            let name = server.project?.name ?? "Port \(server.port)"
            NotificationManager.serverStarted(name: name, port: server.port)
        }

        if !stoppedPIDs.isEmpty {
            // Find metadata from the previous scan for friendly names
            for pid in stoppedPIDs {
                if let old = servers.first(where: { $0.pid == pid }) {
                    let name = old.project?.name ?? "Port \(old.port)"
                    NotificationManager.serverStopped(name: name, port: old.port)
                }
            }
        }

        previousPIDs = newPIDs

        // ── Update history ───────────────────────────────────────────────
        for server in started {
            addToHistory(server)
        }

        self.servers        = sorted(results)
        self.cursorProjects = sorted(detectedCursorProjects)
    }

    // MARK: - Sorting helpers

    private func sorted(_ list: [ServerInfo]) -> [ServerInfo] {
        list.sorted { a, b in
            let pa = pinnedPaths.contains(a.workingDirectory ?? "")
            let pb = pinnedPaths.contains(b.workingDirectory ?? "")
            if pa != pb { return pa }
            return false
        }
    }

    private func sorted(_ list: [CursorProject]) -> [CursorProject] {
        list.sorted { a, b in
            let pa = pinnedPaths.contains(a.path)
            let pb = pinnedPaths.contains(b.path)
            if pa != pb { return pa }
            return false
        }
    }

    // MARK: - Pinned persistence

    private func loadPinned() {
        let saved = UserDefaults.standard.stringArray(forKey: pinnedKey) ?? []
        pinnedPaths = Set(saved)
    }

    private func savePinned() {
        UserDefaults.standard.set(Array(pinnedPaths), forKey: pinnedKey)
    }

    // MARK: - History

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([RecentServer].self, from: data) else { return }
        recentServers = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(recentServers) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func addToHistory(_ server: ServerInfo) {
        let name = server.project?.name ?? "Port \(server.port)"
        let framework = server.project?.framework.rawValue ?? "Unknown"

        // Update lastSeen if already present, otherwise prepend
        if let idx = recentServers.firstIndex(where: { $0.port == server.port && $0.name == name }) {
            recentServers[idx].lastSeen = Date()
        } else {
            let entry = RecentServer(port: server.port, name: name, framework: framework)
            recentServers.insert(entry, at: 0)
        }

        // Keep the last 20 entries
        if recentServers.count > 20 {
            recentServers = Array(recentServers.prefix(20))
        }

        saveHistory()
    }
}
