import Foundation

enum ProjectDetector {

    static func detect(at path: String) -> ProjectInfo {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)

        let name = detectName(at: url, fm: fm)
        let framework = detectFramework(at: url, fm: fm)

        let (launchCommand, rawLaunchScript) = detectLaunchCommand(at: url, fm: fm)

        return ProjectInfo(name: name, framework: framework, path: path, launchCommand: launchCommand, rawLaunchScript: rawLaunchScript)
    }

    // MARK: - Private

    private static func detectName(at url: URL, fm: FileManager) -> String {
        // Resolve to the canonical project path. Claude Code worktrees live at
        // `<project>/.claude/worktrees/<slug>[/subpath]`, and lsof reports the
        // worktree path as cwd — without stripping, the displayed name becomes
        // the worktree slug ("distracted-road-412d36") instead of the project.
        let canonical = canonicalProjectURL(url)
        let last = canonical.lastPathComponent

        // Monorepo subfolders ("frontend", "backend", …) carry no identifying
        // info on their own. Prepend the parent so the row reads "myrepo/frontend".
        let generic: Set<String> = [
            "frontend", "backend", "api", "web", "app", "apps",
            "client", "server", "src", "packages", "site", "www",
        ]
        if generic.contains(last.lowercased()) {
            let parent = canonical.deletingLastPathComponent().lastPathComponent
            if !parent.isEmpty && parent != "/" {
                return "\(parent)/\(last)"
            }
        }

        return last
    }

    /// Strips a `.claude/worktrees/<slug>` segment from the path so the displayed
    /// name reflects the real project, not the throwaway worktree slug. Any subpath
    /// after the slug is preserved (e.g. `<project>/.claude/worktrees/X/frontend`
    /// → `<project>/frontend`).
    private static func canonicalProjectURL(_ url: URL) -> URL {
        let path = url.path
        guard let range = path.range(of: "/.claude/worktrees/") else { return url }

        let beforeClaude = String(path[..<range.lowerBound])
        let afterClaude  = String(path[range.upperBound...])
        let subpath = afterClaude
            .components(separatedBy: "/")
            .dropFirst()   // drop the worktree slug itself
            .joined(separator: "/")

        let resolved = subpath.isEmpty ? beforeClaude : "\(beforeClaude)/\(subpath)"
        return URL(fileURLWithPath: resolved)
    }

    private static func detectFramework(at url: URL, fm: FileManager) -> ProjectInfo.Framework {
        let path = url.path

        // package.json-based detection
        if let data = try? Data(contentsOf: url.appendingPathComponent("package.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            let deps = (json["dependencies"] as? [String: Any] ?? [:])
                .merging(json["devDependencies"] as? [String: Any] ?? [:]) { a, _ in a }

            let scripts = (json["scripts"] as? [String: Any] ?? [:])
                .values.compactMap { $0 as? String }
                .joined(separator: " ")

            if deps["next"] != nil { return .nextjs }
            if deps["nuxt"] != nil { return .nuxt }
            if deps["vite"] != nil { return .vite }
            if deps["vue"] != nil { return .vue }
            if deps["react"] != nil { return .react }
            if deps["express"] != nil { return .express }

            if scripts.contains("next") { return .nextjs }
            if scripts.contains("nuxt") { return .nuxt }
                if scripts.contains("vite") { return .vite }
        }

        // File-system detection
        if fm.fileExists(atPath: "\(path)/artisan") { return .laravel }
        if fm.fileExists(atPath: "\(path)/manage.py") { return .django }
        if fm.fileExists(atPath: "\(path)/config.ru") { return .rails }
        if fm.fileExists(atPath: "\(path)/Gemfile") && fm.fileExists(atPath: "\(path)/app/controllers") { return .rails }
        if fm.fileExists(atPath: "\(path)/wsgi.py") || fm.fileExists(atPath: "\(path)/app.py") { return .flask }

        return .unknown
    }

    /// Returns `(wrapperCommand, rawScriptContent)`.
    /// `wrapperCommand` is e.g. "npm run dev"; `rawScriptContent` is the actual script value
    /// from package.json, e.g. "next dev -p 3000". The raw content lets ProcessManager replace
    /// a hardcoded port flag instead of relying on the PORT env var (which frameworks often ignore).
    private static func detectLaunchCommand(at url: URL, fm: FileManager) -> (String?, String?) {
        let path = url.path

        // Node.js projects: pick best start script
        let packageURL = url.appendingPathComponent("package.json")
        if let data = try? Data(contentsOf: packageURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let scripts = json["scripts"] as? [String: String] {

            let pm = packageManager(at: path, fm: fm)

            // Priority order for common dev-start scripts
            let preferred = ["dev", "start", "develop", "serve"]
            for key in preferred {
                if let rawScript = scripts[key] {
                    return ("\(pm) run \(key)", rawScript)
                }
            }
            // Fall back to first script that isn't build/test/lint
            let excluded = ["build", "test", "lint", "prepare", "postinstall", "preinstall"]
            if let key = scripts.keys.first(where: { !excluded.contains($0) }),
               let rawScript = scripts[key] {
                return ("\(pm) run \(key)", rawScript)
            }
        }

        // PHP / Laravel
        if fm.fileExists(atPath: "\(path)/artisan") {
            return ("php artisan serve", nil)
        }

        // Python / Django
        if fm.fileExists(atPath: "\(path)/manage.py") {
            return ("python manage.py runserver", nil)
        }

        // Python / Flask
        if fm.fileExists(atPath: "\(path)/app.py") {
            return ("flask run", nil)
        }

        // Ruby / Rails
        if fm.fileExists(atPath: "\(path)/config.ru") {
            return ("rails server", nil)
        }

        return (nil, nil)
    }

    /// Detect which package manager is used in a node project
    private static func packageManager(at path: String, fm: FileManager) -> String {
        if fm.fileExists(atPath: "\(path)/bun.lockb") { return "bun" }
        if fm.fileExists(atPath: "\(path)/pnpm-lock.yaml") { return "pnpm" }
        if fm.fileExists(atPath: "\(path)/yarn.lock") { return "yarn" }
        return "npm"
    }
}
