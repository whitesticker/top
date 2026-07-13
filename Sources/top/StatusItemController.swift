import AppKit
import SwiftUI
import Combine

// Owns the NSStatusItem: keeps the menu bar icon in sync with the latest
// network speeds, and shows the dashboard as a genuine NSMenu (not an
// NSPopover) -- one row per metric, each a real NSMenuItem with a native
// `.submenu` for its detail view, plus a trailing Quit item. This is the
// same shape as system status menus like Bluetooth's device list: a
// vertical list of rows, each cascading into its own submenu with no
// anchor arrow anywhere, and immune to Mission Control's window-gathering
// animation the way a real NSPopover window never is. See MenuRows.swift
// for the row/detail views and DetailSubmenu for how each submenu is built.
//
// This replaces an earlier 2-column-grid version (still in DashboardView.swift,
// unused for now) where the whole dashboard was one NSMenuItem and each
// card's "detail" used SwiftUI's `.popover`. That version's compact grid was
// nicer at a glance, but its detail popovers always drew an anchor arrow,
// and there's no way to remove that without each card becoming its own
// top-level menu item -- which is what this version is. Keeping both until
// we know which one wins.
//
// The menu (and every row's NSHostingView) is built exactly once here and
// reused for the app's lifetime; it is never rebuilt/re-added on each
// click. Rebuilding a SwiftUI-backed NSMenuItem repeatedly is a known
// source of memory leaks (FB7539293) -- reusing one instance and letting
// its own @Published state drive updates avoids that entirely.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let monitor: SystemMonitor
    private var rowHostingViews: [NSHostingView<AnyView>] = []
    private var detailSubmenus: [DetailSubmenu] = []
    private var cancellable: AnyCancellable?

    init(monitor: SystemMonitor) {
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        let menu = NSMenu()
        menu.delegate = self

        // Leading separator absorbs NSMenu's own top-inset chrome (its
        // rounded-corner chrome otherwise clips the top of the first row).
        menu.addItem(.separator())

        addRow(to: menu, view: DateRow().environmentObject(monitor))
        menu.addItem(.separator())

        addRow(to: menu, view: CPURow().environmentObject(monitor)) {
            CPUDetailStandalone().environmentObject(monitor)
        }
        addRow(to: menu, view: GPURow().environmentObject(monitor)) {
            GPUDetailStandalone().environmentObject(monitor)
        }
        addRow(to: menu, view: MemoryRow().environmentObject(monitor)) {
            MemoryDetailStandalone().environmentObject(monitor)
        }
        addRow(to: menu, view: NetworkRow().environmentObject(monitor)) {
            NetworkDetailStandalone().environmentObject(monitor)
        }
        addRow(to: menu, view: DiskRow().environmentObject(monitor)) {
            DiskDetailStandalone().environmentObject(monitor)
        }
        addRow(to: menu, view: SensorsRow().environmentObject(monitor)) {
            SensorsDetailStandalone().environmentObject(monitor)
        }
        addRow(to: menu, view: PowerRow().environmentObject(monitor)) {
            PowerDetailStandalone().environmentObject(monitor)
        }

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
        }

        cancellable = monitor.$snapshot
            .map(\.network)
            .receive(on: RunLoop.main)
            .sink { [weak self] net in self?.updateIcon(net) }

        updateIcon(monitor.snapshot.network)
    }

    /// Adds a plain row (no submenu) -- used only for the date/time row.
    private func addRow<V: View>(to menu: NSMenu, view: V) {
        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = NSRect(x: 0, y: 0, width: 300, height: 100)
        warmUp(hosting)
        rowHostingViews.append(hosting)

        let item = NSMenuItem()
        item.view = hosting
        menu.addItem(item)
    }

    /// Adds a row with a native cascading `.submenu` for its detail view.
    private func addRow<V: View, D: View>(to menu: NSMenu, view: V, @ViewBuilder detail: @escaping () -> D) {
        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = NSRect(x: 0, y: 0, width: 300, height: 100)
        warmUp(hosting)
        rowHostingViews.append(hosting)

        let item = NSMenuItem()
        item.view = hosting

        let submenu = DetailSubmenu(content: detail)
        detailSubmenus.append(submenu)
        item.submenu = submenu.menu

        menu.addItem(item)
    }

    // Forces one real SwiftUI layout pass immediately (via a throwaway
    // offscreen window), so `fittingSize` is already trustworthy the very
    // first time this menu opens -- without this, the first open or two
    // can read a wrong (too-short) `fittingSize` in `menuWillOpen` and clip
    // the row's content, since the view has never been part of any real
    // window before that point.
    private func warmUp(_ hosting: NSHostingView<AnyView>) {
        let warmupWindow = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        warmupWindow.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        if fitting.height > 0 {
            hosting.frame = NSRect(origin: .zero, size: fitting)
        }
        warmupWindow.contentView = nil
    }

    // Refines every row's frame to its real SwiftUI-measured size right
    // before the menu displays -- at construction time, SwiftUI hasn't
    // laid any of them out yet, so their `fittingSize` would be wrong.
    func menuWillOpen(_ menu: NSMenu) {
        for hosting in rowHostingViews {
            let fitting = hosting.fittingSize
            guard fitting.height > 0 else { continue }
            hosting.frame = NSRect(origin: .zero, size: fitting)
        }
    }

    private func updateIcon(_ net: NetworkSample) {
        statusItem.button?.image = NetworkIconRenderer.render(
            up: net.upBytesPerSec, down: net.downBytesPerSec)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
