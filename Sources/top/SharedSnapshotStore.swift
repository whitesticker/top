import Foundation
import os
import WidgetKit

// Bridges `SystemSnapshot` between the main menu bar app and the widget
// extension via an App Group's shared UserDefaults suite -- widgets run in
// their own process and can't read the app's in-memory `SystemMonitor`
// state directly. The main app writes its latest snapshot here after every
// poll (see SystemMonitor); the widget's TimelineProvider reads it when
// building a timeline entry.
//
// This uses shared UserDefaults rather than a raw file in the App Group's
// container: a first version wrote a JSON file directly, but reading it
// from the sandboxed widget extension failed with EPERM ("Operation not
// permitted") even though the entitlements matched on both sides --
// direct file access across an App Group between a *non-sandboxed* host
// app and a *sandboxed* extension (extensions are always sandboxed) can
// hit that kernel-level sandbox denial. Shared UserDefaults is brokered by
// cfprefsd rather than a raw file syscall from the sandboxed process, and
// is the standard, well-documented approach for exactly this host-app/
// widget pattern.
//
// WidgetKit only refreshes on its own budgeted schedule (minutes, not
// seconds), so whatever's read here will always be somewhat stale
// compared to the live menu bar dropdown -- that's an inherent limitation
// of widgets, not a bug in this bridge.
//
// This file is compiled into both the "top" app target and the
// "TopWidgetExtension" target (see project.yml) -- it only depends on
// Foundation and Models.swift, both already shared the same way.
enum SharedSnapshotStore {
    static let appGroupID = "group.com.local.top"
    private static let key = "latestSnapshot"
    private static let log = Logger(subsystem: "com.local.top", category: "SharedSnapshotStore")

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // WidgetKit doesn't poll -- without an explicit nudge, a widget only
    // re-reads shared data on its own budgeted schedule (or whenever it
    // happens to relaunch). That's what caused "the widget isn't working":
    // its very first read raced ahead of the main app's first write and
    // cached an empty result, then had no reason to look again for
    // several minutes. `WidgetCenter.reloadAllTimelines()` asks WidgetKit
    // to re-query right away, but the system also rate-limits how often
    // reload requests are honored, so this is throttled to once a minute
    // rather than called on every 5s save -- calling it that often would
    // burn through that budget for no benefit (the widget's own timeline
    // policy already caps effective refreshes to a few minutes anyway).
    private static var lastReloadRequest = Date.distantPast
    private static let reloadInterval: TimeInterval = 60

    /// Called by the main app after every poll. Silently does nothing if
    /// the App Group suite isn't available (e.g. entitlement missing
    /// during local `swift build` runs that aren't the Xcode-built app).
    static func save(_ snapshot: SystemSnapshot) {
        guard let defaults = sharedDefaults else {
            log.error("save: shared UserDefaults suite unavailable")
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot) else {
            log.error("save: failed to encode snapshot")
            return
        }
        defaults.set(data, forKey: key)
        defaults.synchronize()
        log.notice("save: wrote \(data.count) bytes")

        let now = Date()
        if now.timeIntervalSince(lastReloadRequest) > reloadInterval {
            lastReloadRequest = now
            log.notice("save: requesting WidgetCenter.reloadAllTimelines()")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Called by the widget's TimelineProvider. Returns nil if the app
    /// hasn't written a snapshot yet (e.g. first install before the main
    /// app has ever run) or the suite is unavailable.
    static func load() -> SystemSnapshot? {
        guard let defaults = sharedDefaults else {
            log.error("load: shared UserDefaults suite unavailable")
            return nil
        }
        defaults.synchronize()
        guard let data = defaults.data(forKey: key) else {
            log.error("load: no data stored for key")
            return nil
        }
        do {
            return try JSONDecoder().decode(SystemSnapshot.self, from: data)
        } catch {
            log.error("load: decode failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
