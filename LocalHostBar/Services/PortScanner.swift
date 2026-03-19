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
            // Dev tools (not servers)
            "Xcode", "xcodebuild",
            // macOS system processes
            "com.apple", "launchd", "rapportd",
            "ControlCenter", "Finder", "Dock", "WindowServer",
        ]
        let lower = command.lowercased()
        return blocked.contains { b in
            let bl = b.lowercased()
            // Normal match: command contains blocked term
            // Reverse match: blocked term starts with command (handles lsof truncation, e.g. "ControlCe" → "ControlCenter")
            return lower.contains(bl) || bl.hasPrefix(lower)
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
