import SwiftUI

/// Single source of truth for every color used across the app -- both the
/// menu bar dropdown and the widget extension. Views should never write a
/// literal `.blue`/`.green`/etc. or `Color(nsColor:)` -- they reference a
/// semantic name here instead, so the whole app's palette (or its
/// light/dark, vibrancy, and accent behavior) can be changed in one place.
//
// Compiled into both the "top" app target and the "TopWidgetExtension"
// target (see project.yml) so the widget's colors always match the menu
// bar's, rather than drifting via separately hand-picked SwiftUI colors.
enum DashColors {
    // Native system accent color -- the same blue (or whatever the user set
    // in System Settings > Appearance) that macOS uses for the connected
    // network highlight in the Wi-Fi menu, toggle switches, etc. Using
    // `Color.accentColor` instead of a hardcoded `.blue` means this app's
    // highlight automatically matches the user's chosen accent color.
    static let accent = Color.accentColor

    // Status ramp shared by every threshold-based gauge (usage bars, core
    // bars, ring gauges, memory pressure, battery level).
    static let statusGood: Color = .green
    static let statusWarning: Color = .yellow
    static let statusCritical: Color = .red

    // Per-metric line/sparkline colors. `download` reuses the system accent
    // since it's the dashboard's primary/most-glanced-at number.
    static let download = accent
    static let upload: Color = .orange
    static let cpuLine: Color = .blue
    static let gpuLine: Color = .purple
    static let diskRead: Color = .green
    static let diskWrite: Color = .pink

    // Panel background: intentionally not set for the menu bar dropdown.
    // NSPopover/NSMenu already render their own native vibrant chrome (the
    // same blur macOS uses for system menus, e.g. the Wi-Fi dropdown) --
    // painting a SwiftUI `.background()` of any kind (flat color or
    // Material) on the root view just paints over/fights that default
    // instead of letting it show through, which is what produced a flat,
    // muddy tint instead of true vibrancy. See `DashboardView.body`, which
    // has no `.background()`. The widget extension can't inherit that same
    // native vibrancy (it renders in its own process/container), so it uses
    // `cardBackground` as a flat tint against its own `containerBackground`
    // material instead -- same color, adapted context.
    //
    // Cards still need a subtle flat tint (not another material layer) to
    // stay visually grouped against that vibrancy -- stacking a second blur
    // pass on top compounds color casts into the same muddiness.
    static let cardBackground: Color = Color.primary.opacity(0.05)
}
