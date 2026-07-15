# TODO

## macOS widget

Make `top` available as a Notification Center / desktop widget, not just a
menu bar dropdown. **Decided: a real WidgetKit widget** (not a fake
floating-panel substitute).

**Status: built and installed.** Xcode is set up (personal team
"XXA24FWXDW", local development certificate regenerated after the original
had no matching private key locally). `xcodegen` generates `top.xcodeproj`
from `project.yml` -- two targets:

- `top` -- the existing menu bar app (unchanged behavior), now also
  writing its snapshot to an App Group container every 5s
  (`SharedSnapshotStore.save`, called from `SystemMonitor.poll()`).
- `TopWidgetExtension` -- sandboxed WidgetKit extension embedded in
  `top.app/Contents/PlugIns/`. Reads the shared snapshot
  (`SharedSnapshotStore.load`) via `SnapshotProvider`. Ships 8 widgets in
  one `TopWidgetBundle`: CPU/GPU/Memory/Network/Disk/Sensors/Battery
  (small + medium) plus one large "System Overview" combining all seven.

Both targets share `Models.swift`, `Formatters.swift`, and
`SharedSnapshotStore.swift` directly from `Sources/top/` (added to both
target memberships in `project.yml`, not duplicated) -- they only import
Foundation, so no AppKit-only code leaks into the sandboxed widget.

Verified: `xcodebuild -project top.xcodeproj -scheme top -allowProvisioningUpdates build`
succeeds, both targets sign correctly with matching App Group
(`group.com.local.top`) and team ID, and `pluginkit -m` shows
`com.local.top.TopWidgetExtension` registered with the system after
launching `/Applications/top.app`.

**Not yet verified**: actually adding a widget via the Notification
Center/desktop widget gallery and confirming it renders real (non-nil)
data -- needs a human to check System Settings/desktop "Edit Widgets" UI,
not something drivable headlessly.

Known permanent limitation (not a bug): WidgetKit's own refresh budget is
coarse (minutes), so the widget will always lag behind the menu bar
dropdown's live 1s updates.

`build.sh`/`swift build` (SPM) still work unchanged for quick CLI
iteration on the main app alone -- the Xcode project is only needed when
the widget target is involved.

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
