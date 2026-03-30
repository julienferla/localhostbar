# LocalHostBar 🖥️

[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-🍺_Buy_me_a_beer-EA4AAA?style=flat&logo=github-sponsors)](https://github.com/sponsors/julienferla)

> A macOS menu bar app that detects, monitors, and controls your local development servers — built for [Cursor](https://cursor.sh) developers.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![License MIT](https://img.shields.io/badge/license-MIT-green)

## Features

- **Auto-detect** all localhost servers running on your machine (Next.js, Vite, Nuxt, Laravel, Rails, Django, Flask, Express, Vue, React…)
- **Project identification** — reads `package.json`, `composer.json`, and filesystem markers to name and classify each server
- **One-click actions** per server:
  - 🌐 Open in browser
  - ✏️ Open project in Cursor
  - 💻 Open Terminal at project root
  - 🔄 Restart server (auto-selects a free port)
  - ⏹ Stop server
- **Cursor Projects** — detects projects currently open in Cursor that have no server running, with a one-click Start button
- **Smart port management** — when starting a second server, automatically picks a free port (handles hardcoded `-p` flags in npm scripts too)
- **Pinned projects** — pin frequently used projects to the top of the list (persisted across launches)
- **Server history** — remembers recently active servers
- **Notifications** — alerts when a server starts or stops
- **Live polling** every 3 seconds — no configuration needed

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Getting Started

```bash
# Clone the repo
git clone https://github.com/julienferla/localhostbar.git
cd localhostbar

# Generate the Xcode project and open it
make open
```

Then build and run with **⌘R** in Xcode.

## Updates (GitHub Releases)

The app checks the [latest GitHub Release](https://github.com/julienferla/localhostbar/releases/latest) using the public API (no account or token). It stays **open source and free**: it only **notifies** you and opens the release page in the browser so you can **download and install** the new build yourself.

- **Automatic check**: at most once per app session, and only if the last check was more than **24 hours** ago.
- **Manual check**: use the download-circle button in the popover footer.

**Maintainers — keep versions in sync**

1. Bump **`MARKETING_VERSION`** / **`CFBundleShortVersionString`** in Xcode (or `MARKETING_VERSION` in `project.yml` before `xcodegen`).
2. Create a GitHub Release whose **tag** matches that version. A leading `v` is fine (e.g. app `1.2.0` ↔ tag `v1.2.0` or `1.2.0`). The checker compares numeric segments after stripping a leading `v`.
3. Attach your **.dmg** / **.zip** (or whatever you ship) to the release as usual.

If the tag version is greater than the running app’s marketing version, users see an update prompt.

## Project Structure

```
LocalHostBar/
├── App/
│   └── LocalBarApp.swift         # @main entry point, MenuBarExtra
├── Models/
│   ├── ServerInfo.swift          # Active server state model
│   ├── ProjectInfo.swift         # Project metadata & framework enum
│   └── CursorProject.swift       # Cursor-detected project model
├── Services/
│   ├── PortScanner.swift         # lsof-based TCP port detection
│   ├── ProjectDetector.swift     # package.json / filesystem framework detection
│   ├── ProcessManager.swift      # kill, open browser, Cursor, Terminal, port logic
│   ├── CursorDetector.swift      # Reads Cursor's storage.json for open projects
│   ├── NotificationManager.swift # UserNotifications integration
│   ├── GitHubReleaseUpdateChecker.swift  # Latest release vs app version (GitHub API)
│   ├── UpdateCheckController.swift       # Update alerts & session / manual checks
│   └── ServerService.swift       # Polling orchestrator (@MainActor ObservableObject)
└── Views/
    ├── PopoverView.swift          # Main popover layout
    ├── ServerRowView.swift        # Active server row with action buttons
    └── CursorProjectRowView.swift # Cursor project row with Start/Both buttons
```

## How It Works

1. Every 3 seconds, `lsof -i -P -n -sTCP:LISTEN` scans all listening TCP ports
2. Ports on localhost in the range 1024–49999 are filtered (common dev servers)
3. For each port, the working directory of the process is read
4. `ProjectDetector` parses `package.json` / other config files to identify the framework and find the launch command
5. `CursorDetector` reads `~/Library/Application Support/Cursor/storage.json` to find open Cursor workspaces

## License

MIT — see [LICENSE](LICENSE)
