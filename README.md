# LocalHostBar 🖥️

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
