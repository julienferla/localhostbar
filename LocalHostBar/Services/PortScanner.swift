import Foundation

struct RawServerEntry {
    let port: Int
    let pid: Int
    let command: String
}

enum PortScanner {

    static func scan() -> [RawServerEntry] {
        let output = runLsof()
        return parse(output: output)
    }

    static func workingDirectory(for pid: Int) -> String? {
        let args = ["-Fn", "-a", "-d", "cwd", "-p", "\(pid)"]
        guard let output = run(command: "/usr/sbin/lsof", args: args), !output.isEmpty else { return nil }

        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("n") {
                let path = String(line.dropFirst())
                if !path.isEmpty && path != "/" {
                    return path
                }
            }
        }
        return nil
    }

    // MARK: - Private

    private static func runLsof() -> String {
        run(command: "/usr/sbin/lsof", args: ["-i", "-P", "-n", "-sTCP:LISTEN"]) ?? ""
    }

    private static func run(command: String, args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private static func parse(output: String) -> [RawServerEntry] {
        var entries: [RawServerEntry] = []
        var seenPorts: Set<Int> = []

        let lines = output.components(separatedBy: "\n").dropFirst()

        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 9 else { continue }

            let command = String(parts[0])
            guard let pid = Int(parts[1]) else { continue }

            let addressField = String(parts[8])
            guard let port = extractPort(from: addressField) else { continue }

            // Only localhost listeners
            guard isLocalhost(addressField) else { continue }

            // Skip privileged ports
            guard port >= 1024 else { continue }

            // Skip ephemeral/browser ports — dev servers live below 50 000
            guard port < 50_000 else { continue }

            // Skip known non-dev-server processes (browsers, chat apps, system)
            guard !isKnownNonServer(command: command) else { continue }

            // Skip duplicates (same port already captured)
            if seenPorts.contains(port) { continue }
            seenPorts.insert(port)

            entries.append(RawServerEntry(port: port, pid: pid, command: command))
        }

        return entries.sorted { $0.port < $1.port }
    }

    private static func isKnownNonServer(command: String) -> Bool {
        let lower = command.lowercased()
        // Android Debug Bridge — listens on localhost (e.g. 5037); not a browser dev server
        if lower == "adb" || lower.hasSuffix("/adb") || lower == "adb.bin" || lower.hasSuffix("/adb.bin") {
            return true
        }

        let blocked = [
            // Browsers
            "firefox", "Google Chrome", "Chrome Helper", "Safari",
            "Arc", "Brave Browser", "Chromium", "Opera", "Orion",
            // Chat / video
            "Slack", "Discord", "zoom.us", "Teams", "WebEx", "Loom",
            "Beeper",
            // Media
            "Spotify", "Messages", "Mail", "FaceTime",
            // Design tools
            "figma",
            // App subscription helpers (local IPC, not dev servers)
            "SetappAgent", "Setapp", "SetappAge",
            // Dev tools (not servers)
            "Xcode", "xcodebuild",
            // Cursor — extension host / MCP / internal listener (e.g. port 36240), not a dev server
            "Cursor",
            // macOS system processes
            "com.apple", "launchd", "rapportd",
            "ControlCenter", "Finder", "Dock", "WindowServer",
        ]
        return blocked.contains { b in
            let bl = b.lowercased()
            // Normal match: command name contains blocked term (e.g. "Google Chrome Helper")
            if lower.contains(bl) { return true }
            // Reverse match: blocked name starts with command — intended for lsof-truncated
            // process names (e.g. "ControlCe" vs "ControlCenter"). Must require a minimum
            // command length: short names like "go" would otherwise match "google chrome"
            // ("google chrome".hasPrefix("go")), hiding all Go dev servers from the list.
            if lower.count >= 4, bl.hasPrefix(lower) { return true }
            return false
        }
    }

    private static func isLocalhost(_ address: String) -> Bool {
        let localhosts = ["127.0.0.1", "::1", "[::1]", "*", "localhost"]
        for h in localhosts {
            if address.hasPrefix(h + ":") { return true }
        }
        // Also match 0.0.0.0 (all interfaces) — common for dev servers
        if address.hasPrefix("*:") { return true }
        return false
    }

    private static func extractPort(from address: String) -> Int? {
        // Formats: "127.0.0.1:3000", "[::1]:3000", "*:3000", "localhost:3000"
        if let lastColon = address.lastIndex(of: ":") {
            let portStr = String(address[address.index(after: lastColon)...])
            let clean = portStr.replacingOccurrences(of: "(LISTEN)", with: "").trimmingCharacters(in: .whitespaces)
            return Int(clean)
        }
        return nil
    }
}
