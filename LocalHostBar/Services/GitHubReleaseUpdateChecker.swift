import Foundation

/// User-facing failure when the GitHub Releases API does not return a usable latest release.
enum GitHubReleaseUpdateError: LocalizedError {
    /// `GET .../releases/latest` returns 404 when the repo has no published releases yet.
    case noPublishedReleases
    case rateLimited
    case httpFailure(statusCode: Int)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .noPublishedReleases:
            return """
            Aucune release publiée sur GitHub pour ce projet. \
            Créez une release avec un tag de version (ex. v1.0.0) sur le dépôt, \
            puis réessayez.
            """
        case .rateLimited:
            return "Limite d’appels GitHub atteinte. Réessayez dans une heure ou ouvrez la page des releases dans le navigateur."
        case .httpFailure(let code):
            return "Réponse GitHub inattendue (code \(code)). Réessayez plus tard."
        case .invalidPayload:
            return "Réponse GitHub illisible. Réessayez plus tard."
        }
    }
}

/// Compares the running app version to the latest GitHub Release (public API, no token).
/// Stays 100% open source: opens the release page in the browser for manual download.
enum GitHubReleaseUpdateChecker {
    static let owner = "julienferla"
    static let repo = "localhostbar"

    private static let userDefaults = UserDefaults.standard
    private static let lastCheckKey = "LocalHostBar.lastUpdateCheckDate"
    private static let dismissedVersionKey = "LocalHostBar.dismissedUpdateVersion"
    private static let autoCheckInterval: TimeInterval = 24 * 60 * 60

    struct LatestRelease: Sendable {
        let version: String
        let tagName: String
        let releasePageURL: URL
    }

    private struct APIResponse: Decodable {
        let tagName: String
        let htmlUrl: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
        }
    }

    /// Current app marketing version (must match GitHub release tags, e.g. `1.1.0` ↔ tag `v1.1.0`).
    static var currentAppVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    static func normalizeVersion(from tag: String) -> String {
        var t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("v") || t.hasPrefix("V") { t.removeFirst() }
        return t
    }

    /// Returns `.orderedAscending` if `a` is older than `b` (semver-like numeric segments).
    static func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
        let ap = a.split(separator: ".").map { Int($0) ?? 0 }
        let bp = b.split(separator: ".").map { Int($0) ?? 0 }
        let n = max(ap.count, bp.count)
        for i in 0..<n {
            let av = i < ap.count ? ap[i] : 0
            let bv = i < bp.count ? bp[i] : 0
            if av != bv {
                return av < bv ? .orderedAscending : .orderedDescending
            }
        }
        return .orderedSame
    }

    static func shouldRunAutomaticCheck() -> Bool {
        guard let last = userDefaults.object(forKey: lastCheckKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) >= autoCheckInterval
    }

    static func recordCheckCompleted() {
        userDefaults.set(Date(), forKey: lastCheckKey)
    }

    static func dismissUpdate(version: String) {
        userDefaults.set(version, forKey: dismissedVersionKey)
    }

    static func isDismissed(_ normalizedVersion: String) -> Bool {
        userDefaults.string(forKey: dismissedVersionKey) == normalizedVersion
    }

    static func fetchLatestRelease() async throws -> LatestRelease {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue(
            "LocalHostBar/\(currentAppVersion) (https://github.com/\(owner)/\(repo))",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubReleaseUpdateError.invalidPayload
        }
        switch http.statusCode {
        case 200...299:
            break
        case 404:
            throw GitHubReleaseUpdateError.noPublishedReleases
        case 403:
            throw GitHubReleaseUpdateError.rateLimited
        default:
            throw GitHubReleaseUpdateError.httpFailure(statusCode: http.statusCode)
        }
        let decoded: APIResponse
        do {
            decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            throw GitHubReleaseUpdateError.invalidPayload
        }
        guard let pageURL = URL(string: decoded.htmlUrl) else {
            throw GitHubReleaseUpdateError.invalidPayload
        }
        let normalized = normalizeVersion(from: decoded.tagName)
        return LatestRelease(version: normalized, tagName: decoded.tagName, releasePageURL: pageURL)
    }

    static func updateAvailable(comparedTo current: String, latest: LatestRelease) -> Bool {
        compareVersions(current, latest.version) == .orderedAscending
    }
}
