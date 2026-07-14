# TODO

## macOS widget

Make `top` available as a Notification Center / desktop widget, not just a
menu bar dropdown. **Decided: a real WidgetKit widget** (not a fake
floating-panel substitute).

Status: blocked on Xcode. This machine currently has only the Command Line
Tools installed — `xcodebuild` refuses to build app-extension targets
(entitlements, provisioning, code signing between host app + extension)
without the full Xcode.app. Getting Xcode requires signing in with an
Apple ID (App Store or developer.apple.com), but it can be a completely
free one — no paid Apple Developer Program membership needed for local
development/signing/App Groups on your own Mac; paid membership only
matters for notarized distribution outside this machine (same situation
`top.app` is already in today — ad-hoc signed, not notarized).

**Next step**: user is installing Xcode. Once it's ready, come back here —
don't generate the `.xcodeproj`/widget target beforehand, since none of it
can be built or verified without Xcode present, and getting the project
file structure right on the first guess is unlikely.

Plan once Xcode is available:
1. Create an Xcode project with two targets: the existing menu bar app,
   and a new WidgetKit extension.
2. Add an App Group entitlement to both targets so they can share data —
   widgets run in their own process and can't read the menu bar app's
   in-memory `SystemMonitor` state directly.
3. Have the main app periodically write its latest snapshot somewhere the
   widget can read (e.g. shared `UserDefaults(suiteName:)` in the App
   Group container, or a small JSON file there).
4. Build the widget's `TimelineProvider`, reading that shared snapshot.
   Note: WidgetKit budgets refresh frequency (minutes, not seconds) — the
   widget will always show slightly-stale data, not the live 1s view the
   menu bar dropdown has. Decide what subset of metrics fit a widget's
   small/medium/large sizes.
5. Decide how `build.sh` and the existing manual build flow relate to the
   new Xcode project (likely: `build.sh` retired in favor of `xcodebuild`,
   or kept only for quick CLI iteration on the main app while the widget
   requires the full project).

## App icon

No `.icns` / `AppIcon` asset exists yet — `build.sh` doesn't set
`CFBundleIconFile`, so the app currently uses the generic default icon.

- Need actual artwork (not just a system symbol) sized for the standard
  macOS icon set (16/32/128/256/512, @1x and @2x).
- Once artwork exists: generate the `.iconset` / `.icns` (e.g. via
  `iconutil`), add it to the app bundle in `build.sh`, and set
  `CFBundleIconFile` in the generated `Info.plist`.

## Control panel / preferences

A settings window (opened from the menu, e.g. a "Preferences…" item above
Quit) to let users customize:

- **Display order** — which order CPU/GPU/Memory/Network/Disk/Sensors/
  Battery rows appear in, or hide ones they don't care about. Needs the row
  order to become user-configurable state (persisted, e.g. `UserDefaults`)
  instead of the hardcoded sequence in `StatusItemController.init`.
- Other customization to consider (not decided yet — discuss before
  building):
  - Poll interval (currently fixed at 1s in `SystemMonitor`)
  - Which stats show in the compact row vs. only in the detail submenu
  - Temperature unit (°C/°F)
  - Launch-at-login toggle (currently manual via System Settings)
