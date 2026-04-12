import Foundation

struct ProjectInfo: Equatable {
    let name: String
    let framework: Framework
    let path: String
    let launchCommand: String?
    /// Raw content of the chosen npm script, e.g. "next dev -p 3000".
    /// Used to replace a hardcoded port flag instead of relying on the PORT env var.
    let rawLaunchScript: String?

    enum Framework: String, CaseIterable {
        case nextjs   = "Next.js"
        case nuxt     = "Nuxt"
        case vite     = "Vite"
        case react    = "React"
        case vue      = "Vue"
        case express  = "Express"
        case laravel  = "Laravel"
        case rails    = "Rails"
        case django   = "Django"
        case flask    = "Flask"
        case unknown  = "Dev Server"

        /// Default listen port when the dev script does not specify `-p` / `--port` (used for auto-restart wait).
        var typicalDevServerPort: Int {
            switch self {
            case .nextjs, .nuxt, .react, .rails, .express: return 3000
            case .vite, .vue: return 5173
            case .laravel, .django: return 8000
            case .flask: return 5000
            case .unknown: return 3000
            }
        }

        var emoji: String {
            switch self {
            case .nextjs:  return "▲"
            case .nuxt:    return "💚"
            case .vite:    return "⚡"
            case .react:   return "⚛️"
            case .vue:     return "🟢"
            case .express: return "🚂"
            case .laravel: return "🔴"
            case .rails:   return "💎"
            case .django:  return "🐍"
            case .flask:   return "🧪"
            case .unknown: return "🔷"
            }
        }
    }
}
