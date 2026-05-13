import AppKit
import Combine
import Foundation

/// Shown inside the menu bar window (not a system alert) so dismissing it does not close the window.
struct UpdateStatusBanner: Equatable {
    enum Kind: Equatable {
        case upToDate
        case checkFailed
    }

    let kind: Kind
    let message: String
}

@MainActor
final class UpdateCheckController: ObservableObject {
    @Published private(set) var updateAvailable: GitHubReleaseUpdateChecker.LatestRelease?
    @Published var showUpdateAlert = false
    @Published var statusBanner: UpdateStatusBanner?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isChecking = false

    func dismissStatusBanner() {
        statusBanner = nil
    }

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
        // Defer to the next runloop tick: when triggered from the menu-bar alert,
        // dismissing the alert in the same turn swallows the NSWorkspace.open call
        // and the browser only launches on a second attempt.
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens the release page and closes the alert (user intends to update; do not treat as "remind later").
    func openReleaseAndDismiss() {
        // Capture the URL before nil-ing `updateAvailable`, then dispatch the open
        // after the alert has dismissed so AppKit does not eat the workspace call.
        let url = updateAvailable?.releasePageURL
        showUpdateAlert = false
        updateAvailable = nil
        if let url {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
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
                statusBanner = UpdateStatusBanner(
                    kind: .upToDate,
                    message: "Vous utilisez la dernière version : \(current)."
                )
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            if manual, let msg = lastErrorMessage {
                statusBanner = UpdateStatusBanner(kind: .checkFailed, message: msg)
            }
        }
    }
}
