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
        // A request, not a guarantee -- WidgetKit applies its own refresh
        // budget on top of this, so the widget is always somewhat behind
        // the live menu bar dropdown.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}
