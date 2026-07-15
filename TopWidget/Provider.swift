import WidgetKit

// Shared by every widget in this extension -- they all read the same
// underlying SystemSnapshot (via the App Group, see SharedSnapshotStore)
// and just render different slices of it.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: SystemSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: SharedSnapshotStore.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: SharedSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), snapshot: SharedSnapshotStore.load())
        // A short-lived entry plus `.atEnd` (rather than an `.after(date)`
        // set minutes out) matches the reference exelban/stats widgets'
        // pattern: keep the entry's validity window close to the actual
        // data cadence (SystemMonitor writes every 1s) so WidgetKit
        // considers this stale and worth re-querying almost immediately,
        // rather than sitting on a "still fresh" entry for a long window.
        // Actual refresh frequency is still gated by the system's own
        // visibility-based budget -- this just stops us from being the
        // bottleneck below whatever that budget allows.
        let entryValidUntil = Date().addingTimeInterval(1)
        completion(Timeline(entries: [SnapshotEntry(date: entryValidUntil, snapshot: entry.snapshot)], policy: .atEnd))
    }
}
