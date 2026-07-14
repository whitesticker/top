import SwiftUI
import AppKit

// MARK: - Row identity

/// The set of reorderable/hideable metric rows in the main menu. Date/Time
/// isn't included -- it's a fixed header, not a "metric" to reorder.
enum MetricRow: String, CaseIterable, Codable, Identifiable {
    case cpu, gpu, memory, network, disk, sensors, battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .memory: return "Memory"
        case .network: return "Network"
        case .disk: return "Disk"
        case .sensors: return "Sensors"
        case .battery: return "Battery"
        }
    }

    var systemImage: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "cube.transparent"
        case .memory: return "memorychip"
        case .network: return "network"
        case .disk: return "internaldrive"
        case .sensors: return "thermometer.medium"
        case .battery: return "battery.100"
        }
    }
}

// MARK: - Persisted preferences

/// User-configurable row order/visibility for the main menu, persisted in
/// UserDefaults. `StatusItemController` builds every row's NSMenuItem once
/// (same reused-forever policy as everything else in that class) and just
/// re-inserts those existing items into the menu in this order whenever it
/// changes -- no view recreation, so no risk of the SwiftUI-in-NSMenuItem
/// memory leak that comes from rebuilding hosting views repeatedly.
final class PreferencesStore: ObservableObject {
    static let shared = PreferencesStore()

    @Published var rowOrder: [MetricRow] {
        didSet { save() }
    }
    @Published var hiddenRows: Set<MetricRow> {
        didSet { save() }
    }

    private let orderKey = "com.local.top.rowOrder"
    private let hiddenKey = "com.local.top.hiddenRows"

    private init() {
        let defaults = UserDefaults.standard

        if let saved = defaults.stringArray(forKey: orderKey) {
            let parsed = saved.compactMap { MetricRow(rawValue: $0) }
            // Any case not present in saved data (e.g. a metric added in a
            // later app version) gets appended at the end rather than lost.
            let missing = MetricRow.allCases.filter { !parsed.contains($0) }
            rowOrder = parsed + missing
        } else {
            rowOrder = MetricRow.allCases
        }

        if let saved = defaults.stringArray(forKey: hiddenKey) {
            hiddenRows = Set(saved.compactMap { MetricRow(rawValue: $0) })
        } else {
            hiddenRows = []
        }
    }

    var visibleRowsInOrder: [MetricRow] {
        rowOrder.filter { !hiddenRows.contains($0) }
    }

    func isHidden(_ row: MetricRow) -> Bool {
        hiddenRows.contains(row)
    }

    func setHidden(_ hidden: Bool, for row: MetricRow) {
        if hidden {
            hiddenRows.insert(row)
        } else {
            hiddenRows.remove(row)
        }
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        rowOrder.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    private func save() {
        UserDefaults.standard.set(rowOrder.map(\.rawValue), forKey: orderKey)
        UserDefaults.standard.set(hiddenRows.map(\.rawValue), forKey: hiddenKey)
    }
}

// MARK: - Preferences UI

struct PreferencesView: View {
    @ObservedObject var store = PreferencesStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Menu Bar Display Order")
                .font(.system(size: 13, weight: .semibold))
            Text("Drag to reorder. Toggle off to hide from the menu.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            List {
                ForEach(store.rowOrder) { row in
                    RowPreferenceCard(row: row)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
                }
                .onMove { indices, newOffset in
                    store.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .frame(minHeight: 320)
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 360)
        .background(.regularMaterial)
    }
}

/// One reorderable row, styled to match the menu's own cards (same
/// background fill, same icon+title language) rather than a plain default
/// List row -- the whole point is that this should feel like it belongs to
/// the same app as the menu, not a generic settings list.
private struct RowPreferenceCard: View {
    @ObservedObject var store = PreferencesStore.shared
    let row: MetricRow

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.4))
            Image(systemName: row.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 18)
            Text(row.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { !store.isHidden(row) },
                set: { store.setHidden(!$0, for: row) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DashStyle.cardCorner, style: .continuous)
                .fill(DashColors.cardBackground)
        )
    }
}

/// Owns the Preferences window. Kept alive by `StatusItemController` for
/// the app's lifetime and reused (shown/raised) rather than recreated each
/// time "Preferences…" is chosen.
final class PreferencesWindowController: NSWindowController {
    convenience init() {
        let hosting = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "top Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        // Non-opaque + clear background so the SwiftUI `.regularMaterial`
        // on PreferencesView gets genuine "behind window" vibrancy (a real
        // blur of whatever's behind this window), matching the menu's own
        // look, instead of just a flat gray -- a normal opaque window would
        // only let Material blur its own already-drawn content, not reach
        // through to the desktop.
        window.isOpaque = false
        window.backgroundColor = .clear
        self.init(window: window)
    }
}
