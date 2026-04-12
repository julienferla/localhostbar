import AppKit
import Darwin
import Foundation

enum ProcessManager {

    // MARK: - Stop

    @discardableResult
    static func stop(pid: Int) -> Bool {
        kill(pid_t(pid), SIGTERM) == 0
    }

    // MARK: - Open in Browser

    static func openInBrowser(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Open in Cursor

    /// Opens a folder in Cursor, found via bundle ID (works regardless of app name like "Cursor 2").
    static func openInCursor(path: String) {
        let bundleID = "com.todesktop.230313mzl4w4u92"

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open(
                [URL(fileURLWithPath: path)],
                withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
            return
        }

        // Fallback: search common paths
        let candidatePaths = [
            "/Applications/Cursor.app",
            "/Applications/Cursor 2.app",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/Applications/Cursor.app"
        ]
        for appPath in candidatePaths where FileManager.default.fileExists(atPath: appPath) {
            NSWorkspace.shared.open(
                [URL(fileURLWithPath: path)],
                withApplicationAt: URL(fileURLWithPath: appPath),
                configuration: NSWorkspace.OpenConfiguration()
            )
            return
        }
    }

    // MARK: - Open Terminal

    /// Opens Terminal at `path`, optionally running a command after `cd`.
    ///
    /// Port strategy (when `autoPort` is true):
    /// 1. If `rawLaunchScript` contains a hardcoded port flag (`-p NNNN` or `--port NNNN`),
    ///    replace the number in-place and run the raw script via local node_modules binaries.
    ///    e.g. `"next dev -p 3000"` → `PATH="…/node_modules/.bin:$PATH" next dev -p 3001`
    /// 2. Otherwise, prepend `PORT=xxxx` to the npm wrapper command (works for most frameworks).
    ///
    /// Pass `occupiedPorts` (ports currently used by running servers) for reliable port selection.
    /// Pass `framework` when `autoPort` is false so auto-restart can wait on the correct default port.
    static func openTerminal(
        at path: String,
        command: String? = nil,
        rawLaunchScript: String? = nil,
        autoPort: Bool = false,
        autoRestart: Bool = false,
        occupiedPorts: Set<Int> = [],
        framework: ProjectInfo.Framework? = nil
    ) {
        let safePath = path.replacingOccurrences(of: "'", with: "\\'")
        var cd = "cd '\(safePath)'"

        if let cmd = command {
            var fullCmd: String
            /// Port the dev server is expected to bind (for pre-launch wait when auto-restarting).
            let effectiveListenPort: Int

            if autoPort {
                let port = findFreePort(excluding: occupiedPorts)
                effectiveListenPort = port

                // Try to patch the hardcoded port flag inside the raw script first.
                if let raw = rawLaunchScript,
                   let patched = replacingPortFlag(in: raw, with: port) {
                    // Run the raw binary directly, prepending local node_modules/.bin
                    let nodeModulesBin = "\(path)/node_modules/.bin"
                    fullCmd = "PATH=\"\(nodeModulesBin):$PATH\" \(patched)"
                } else {
                    // Fall back: inject PORT env var before the npm wrapper command.
                    fullCmd = "PORT=\(port) \(cmd)"
                }
            } else {
                fullCmd = cmd
                effectiveListenPort = explicitPort(in: rawLaunchScript)
                    ?? framework?.typicalDevServerPort
                    ?? 3000
            }

            // Wrap in a while loop so the server restarts automatically in the same
            // Terminal window if it crashes (Ctrl-C still exits cleanly).
            if autoRestart {
                // Avoid EADDRINUSE: wait until the previous process has released the socket
                // (Node/Next can take >3s to tear down after a crash).
                let wait = bashWaitUntilPortFree(port: effectiveListenPort)
                fullCmd = "while true; do \(wait); \(fullCmd); echo ''; echo '🔄 Redémarrage dans 3s... (Ctrl+C pour arrêter)'; sleep 3; done"
            }

            let safeCmd = fullCmd.replacingOccurrences(of: "\"", with: "\\\"")
            cd += " && \(safeCmd)"
        }

        let script = """
        tell application "Terminal"
            activate
            do script "\(cd)"
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if error == nil { return }
        }

        // Fallback: just open Terminal.app
        NSWorkspace.shared.launchApplication("Terminal")
    }

    // MARK: - Restart

    /// Stops the server, frees the listen port, closes **all** Terminal.app windows, then opens one fresh window.
    /// Fermer toutes les fenêtres évite les boucles `while true` orphelines et les conflits de port ; tout autre travail ouvert dans Terminal est perdu.
    static func restart(server: ServerInfo, occupiedPorts: Set<Int> = [], autoRestart: Bool = false) {
        stop(pid: server.pid)
        killListeners(on: server.port)
        closeAllTerminalWindows()

        guard let path = server.workingDirectory,
              let cmd = server.project?.launchCommand else { return }
        // Remove the restarted server's own port so it can reclaim it after stopping.
        var ports = occupiedPorts
        ports.remove(server.port)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            openTerminal(
                at: path,
                command: cmd,
                rawLaunchScript: server.project?.rawLaunchScript,
                autoPort: true,
                autoRestart: autoRestart,
                occupiedPorts: ports,
                framework: server.project?.framework
            )
        }
    }

    /// Sends SIGKILL to any process still in TCP LISTEN on `port` (ex. Node orbeline après crash).
    private static func killListeners(on port: Int) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [
            "-c",
            "lsof -tiTCP:\(port) -sTCP:LISTEN 2>/dev/null | xargs kill -9 2>/dev/null; true"
        ]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
    }

    /// Ferme toutes les fenêtres de Terminal.app sans enregistrer (`saving no`).
    private static func closeAllTerminalWindows() {
        let script = """
        tell application "Terminal"
            repeat while (count of windows) > 0
                try
                    close front window saving no
                on error
                    exit repeat
                end try
            end repeat
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }

    // MARK: - Auto-restart / port wait (bash)

    /// Bash snippet: block until nothing is listening on `port` (max ~30s), then continue.
    /// Prevents `EADDRINUSE` when the prior dev server has not finished releasing the socket.
    private static func bashWaitUntilPortFree(port: Int) -> String {
        "LHB_P=\(port); for __lhb in $(seq 1 30); do lsof -iTCP:$LHB_P -sTCP:LISTEN -P -n >/dev/null 2>&1 || break; sleep 1; done"
    }

    /// Parses `-p N` or `--port N` from an npm script line, if present.
    private static func explicitPort(in script: String?) -> Int? {
        guard let script = script else { return nil }
        let pattern = #"(?:-p|--port)\s+(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: script, range: NSRange(script.startIndex..., in: script)),
              let range = Range(match.range(at: 1), in: script) else { return nil }
        return Int(script[range])
    }

    // MARK: - Port-flag replacement

    /// Scans `script` for `-p NNNN` or `--port NNNN` and replaces the number with `port`.
    /// Returns `nil` if no such flag is found (caller should fall back to PORT= env var).
    static func replacingPortFlag(in script: String, with port: Int) -> String? {
        // Match: (-p|--port)\s+(\d+)
        let pattern = #"(-p|--port)\s+(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: script, range: NSRange(script.startIndex..., in: script)) else {
            return nil
        }
        // Replace just the numeric group.
        var result = script
        if let range = Range(match.range(at: 2), in: script) {
            result.replaceSubrange(range, with: "\(port)")
        }
        return result
    }

    // MARK: - Port utilities

    /// Finds the first available TCP port starting from `base`.
    /// `excluding` should contain ports already known to be occupied (from ServerService).
    static func findFreePort(startingFrom base: Int = 3000, excluding: Set<Int> = []) -> Int {
        var port = base
        while port < 65_000 {
            // First check the fast in-memory list, then confirm with lsof.
            if !excluding.contains(port) && !isPortListening(port) { return port }
            port += 1
        }
        return base
    }

    /// Returns true if something is already listening on `port` (uses lsof — same tool as PortScanner).
    private static func isPortListening(_ port: Int) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        // -iTCP:<port>  — filter on this TCP port
        // -P            — don't convert port numbers to names
        // -n            — don't resolve hostnames
        // -sTCP:LISTEN  — only LISTEN state sockets
        process.arguments = ["-iTCP:\(port)", "-P", "-n", "-sTCP:LISTEN"]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()

        do { try process.run() } catch { return false }
        // Read stdout BEFORE waitUntilExit to avoid deadlock on full pipe buffer.
        _ = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        // lsof exits 0 if it found at least one match, 1 if nothing matches.
        return process.terminationStatus == 0
    }
}
