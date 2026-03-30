import AppKit
import Combine
import Foundation

@MainActor
final class UpdateCheckController: ObservableObject {
    @Published private(set) var updateAvailable: GitHubReleaseUpdateChecker.LatestRelease?
    @Published var showUpdateAlert = false
    @Published var showUpToDateAlert = false
    @Published var showCheckFailedAlert = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isChecking = false

    private var didRunSessionAutoCheck = false

    /// Call when the popover appears: one automatic check per app session, throttled by UserDefaults (24h).
    func performSessionAutoCheckIfNeeded() async {
        guard !didRunSessionAutoCheck else { return }
        didRunSessionAutoCheck = true
        guard GitHubReleaseUpdateChecker.shouldRunAutomaticCheck() else { return }
        await checkForUpdates(manual: false)
    }

    /// User-initiated from footer; always hits the API and shows a result.
    func checkForUpdatesManual() async {
        await checkForUpdates(manual: true)
    }

    func openReleasePage() {
        guard let url = updateAvailable?.releasePageURL else { return }
        NSWorkspace.shared.open(url)
    }

    /// Opens the release page and closes the alert (user intends to update; do not treat as "remind later").
    func openReleaseAndDismiss() {
        openReleasePage()
        showUpdateAlert = false
        updateAvailable = nil
    }

    func remindLater() {
        if let v = updateAvailable?.version {
            GitHubReleaseUpdateChecker.dismissUpdate(version: v)
        }
        showUpdateAlert = false
        updateAvailable = nil
    }

    private func checkForUpdates(manual: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        lastErrorMessage = nil
        defer { isChecking = false }

        do {
            let latest = try await GitHubReleaseUpdateChecker.fetchLatestRelease()
            GitHubReleaseUpdateChecker.recordCheckCompleted()

            let current = GitHubReleaseUpdateChecker.currentAppVersion
            let newer = GitHubReleaseUpdateChecker.updateAvailable(comparedTo: current, latest: latest)

            if newer {
                if !manual, GitHubReleaseUpdateChecker.isDismissed(latest.version) {
                    return
                }
                updateAvailable = latest
                showUpdateAlert = true
            } else if manual {
                showUpToDateAlert = true
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            if manual {
                showCheckFailedAlert = true
            }
        }
    }
}
