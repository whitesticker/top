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
    // Must match the App Group identifier in both targets' entitlements:
    // "$(TeamIdentifierPrefix)com.local.top.widgets". That prefix resolves
    // to the team ID at codesign time, so at runtime we reconstruct the
    // same string from a literal "TeamId" key each target's Info.plist
    // carries (see project.yml / TopWidget/Info.plist). A plain
    // "group.com.local.top" identifier (no team prefix) looked valid in
    // entitlements but never actually worked for cross-process sharing
    // under this personal-team automatic-signing setup.
    static let appGroupID: String = {
        guard let teamId = Bundle.main.object(forInfoDictionaryKey: "TeamId") as? String else {
            return "com.local.top.widgets"
        }
        return "\(teamId).com.local.top.widgets"
    }()
    private static let key = "latestSnapshot"
    private static let log = Logger(subsystem: "com.local.top", category: "SharedSnapshotStore")

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // Turns out WidgetKit's reload budget is generous for a *visible*
    // widget (Desktop-placed, or an open Notification Center) -- the
    // exelban/stats reference app calls reloadTimelines() on essentially
    // every 1s module tick and its widgets stay live. The "budget
    // exhausted" theory from the previous version of this comment was
    // half right: throttling to once a minute (or once per 15 minutes)
    // didn't fix stale widgets because the actual gate is visibility, not
    // call frequency -- a widget sitting in a *closed* Notification Center
    // is treated as not-visible and barely refreshes no matter how often
    // reloadAllTimelines() is called. So: request a reload on every save
    // (matching stats' per-tick pattern) and rely on the system's own
    // visibility-based throttling rather than self-imposing one. For a
    // near-continuous refresh, place the widget on the Desktop rather than
    // (or in addition to) Notification Center.
    private static var lastReloadRequest = Date.distantPast
    private static let minReloadGap: TimeInterval = 1

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
        if now.timeIntervalSince(lastReloadRequest) > minReloadGap {
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
            let snapshot = try JSONDecoder().decode(SystemSnapshot.self, from: data)
            log.notice("load: succeeded, \(data.count) bytes")
            return snapshot
        } catch {
            log.error("load: decode failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
