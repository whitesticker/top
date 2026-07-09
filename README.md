# top

A lightweight, native macOS menu bar system monitor — an iStat Menus alternative
focused on simplicity and performance. Shows live network upload/download speed
right in the menu bar, with a click-through dashboard for everything else.

## Features

- **Menu bar icon**: live ↑/↓ network speed, fixed-width so it never jitters
- **Dashboard** (click the icon): CPU, GPU, Memory, Network, Disk, Sensors,
  Battery & Power, Date & Time — all in one compact, no-scroll view
- **Detail popovers**: click any section for the full picture (e.g. every
  individual temperature sensor, every disk volume, every network interface)
- **Right-click** the icon to quit
- Pure Swift + AppKit/SwiftUI, no Electron, no third-party dependencies,
  minimal CPU/memory footprint (polls system APIs directly via IOKit/sysctl)

## Requirements

- macOS 13 or later (Apple Silicon or Intel)
- No Xcode required to build — just the Swift toolchain from Xcode Command
  Line Tools (`xcode-select --install`)

## Building from source

```sh
git clone https://github.com/<you>/top.git
cd top
./build.sh
open build/top.app
```

`build.sh` compiles everything with `swiftc` directly and assembles the
`.app` bundle by hand — no Xcode project needed. It auto-detects a matching
macOS SDK if your default one doesn't line up with your compiler version.

To have it launch automatically at login, drag `build/top.app` into
System Settings → General → Login Items.

### Note on Gatekeeper

This build is ad-hoc signed (not notarized by Apple), so macOS may warn that
it "cannot be opened" the first time you run it. Right-click the app in
Finder and choose **Open** (instead of double-clicking) to bypass this once,
or run:

```sh
xattr -d com.apple.quarantine build/top.app
```

## Installing via Homebrew

```sh
brew tap <you>/top
brew install --cask top
```

*(coming soon)*

## Architecture

- `Sources/top/Models.swift` — shared data structures for every metric
- `Sources/top/*Monitor.swift` — one collector per category (CPU, GPU,
  Memory, Network, Disk, Sensors, Power), each polling the relevant system
  API directly (`host_processor_info`, IOKit registry, `sysctl`, SMC)
- `Sources/top/SystemMonitor.swift` — central polling loop, publishes
  snapshots + history buffers for sparklines
- `Sources/top/StatusItemController.swift` — owns the `NSStatusItem` and
  popover
- `Sources/top/DashboardView.swift` + `Components.swift` — the SwiftUI
  dashboard

## License

MIT — see [LICENSE](LICENSE).
