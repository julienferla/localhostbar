import Foundation

enum CursorDetector {

    /// Returns all projects currently open in Cursor (based on storage.json),
    /// mapped to CursorProject with framework + launch command info.
    static func openProjects() -> [CursorProject] {
        let fm = FileManager.default
        return readOpenPaths()
            .filter { fm.fileExists(atPath: $0) }
            .compactMap { path -> CursorProject? in
                let info = ProjectDetector.detect(at: path)
                return CursorProject(
                    path: path,
                    name: info.name,
                    framework: info.framework,
                    launchCommand: info.launchCommand,
                    rawLaunchScript: info.rawLaunchScript
                )
            }
    }

    // MARK: - Private

    private static func readOpenPaths() -> [String] {
        var paths: [String] = []

        // Primary location (newer Cursor / VS Code)
        let primary = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/storage.json")
        if let json = loadJSON(at: primary) {
            paths += extractPaths(from: json)
        }

        // Legacy location
        let legacy = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/storage.json")
        if let json = loadJSON(at: legacy) {
            paths += extractPaths(from: json)
        }

        // Deduplicate, preserve order
        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }

    private static func loadJSON(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func extractPaths(from json: [String: Any]) -> [String] {
        var paths: [String] = []

        // windowsState.openedWindows — key is "folder" (file URI), not "folderPath"
        if let state = json["windowsState"] as? [String: Any] {
            if let windows = state["openedWindows"] as? [[String: Any]] {
                for window in windows {
                    if let path = folderPath(from: window) { paths.append(path) }
                }
            }
            if let last = state["lastActiveWindow"] as? [String: Any],
               let path = folderPath(from: last) {
                paths.append(path)
            }
        }

        // backupWorkspaces.folders — fallback (recently open folders)
        if let backup = json["backupWorkspaces"] as? [String: Any],
           let folders = backup["folders"] as? [[String: Any]] {
            for folder in folders {
                if let path = folderPath(from: folder) { paths.append(path) }
            }
        }

        // openedPathsList.workspaces3 — legacy VS Code format
        if let list = json["openedPathsList"] as? [String: Any],
           let workspaces = list["workspaces3"] as? [[String: Any]] {
            for ws in workspaces {
                if let path = folderPath(from: ws) { paths.append(path) }
            }
        }

        return paths
    }

    /// Extracts a filesystem path from a dict that may contain
    /// "folder", "folderUri", or "folderPath" as a file:// URI or plain path.
    private static func folderPath(from dict: [String: Any]) -> String? {
        let candidates = ["folder", "folderUri", "folderPath"]
        for key in candidates {
            guard let value = dict[key] as? String else { continue }
            if value.hasPrefix("file://") {
                // URL-decode percent-encoded characters (e.g. %20 → space)
                if let url = URL(string: value), url.scheme == "file" {
                    return url.path
                }
            } else if value.hasPrefix("/") {
                return value
            }
        }
        return nil
    }
}
