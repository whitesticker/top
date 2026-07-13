import AppKit
import SwiftUI
import Combine

// Owns the NSStatusItem: keeps the menu bar icon in sync with the latest
// network speeds, and shows the SwiftUI dashboard as a genuine NSMenu (not
// an NSPopover), with a custom NSHostingView as its one item, plus a
// trailing Quit item -- exactly the same shape as the system Wi-Fi/Bluetooth
// dropdowns (a rich custom area followed by a couple of plain actions).
//
// This replaced an NSPopover-based version. NSPopover is a real NSWindow, so
// even with its own animation disabled it still gets swept up in Mission
// Control's window-gathering transition (a visible shrink-to-center) and
// always draws an anchor arrow. NSMenu lives in a layer Mission Control
// excludes from that transition entirely and never draws an arrow, which is
// why every native status-bar menu (and most polished third-party menu bar
// apps) uses NSMenu, not NSPopover -- this is Apple's own stated guidance
// for menu bar extras.
//
// The menu (and its NSHostingView) is built exactly once here and reused for
// the app's lifetime; it is never rebuilt/re-added on each click. Rebuilding
// a SwiftUI-backed NSMenuItem repeatedly is a known source of memory leaks
// (FB7539293) -- reusing one instance and letting its own @Published state
// drive updates avoids that entirely.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let monitor: SystemMonitor
    private let hostingView: NSHostingView<AnyView>
    private var cancellable: AnyCancellable?

    init(monitor: SystemMonitor) {
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hostingView = NSHostingView(rootView: AnyView(DashboardView().environmentObject(monitor)))
        // Placeholder frame -- SwiftUI hasn't laid out the view yet at this
        // point, so `fittingSize` here would report a too-short height and
        // clip the dashboard's top row. Refined to the real size in
        // `menuWillOpen`, once a layout pass has actually happened.
        hostingView.frame = NSRect(x: 0, y: 0, width: 340, height: 600)

        super.init()

        let menu = NSMenu()
        menu.delegate = self

        // NSMenu reserves a few points at the top of its very first item for
        // its own rounded-corner chrome, which otherwise clips the top of
        // whatever view sits there (here, the dashboard's CPU/GPU header
        // row). A leading separator absorbs that inset instead of our
        // content -- it isn't visible since there's nothing above it to
        // divide from.
        menu.addItem(.separator())

        let dashboardItem = NSMenuItem()
        dashboardItem.view = hostingView
        menu.addItem(dashboardItem)

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

    func menuWillOpen(_ menu: NSMenu) {
        let fitting = hostingView.fittingSize
        guard fitting.height > 0 else { return }
        hostingView.frame = NSRect(origin: .zero, size: fitting)
    }

    private func updateIcon(_ net: NetworkSample) {
        statusItem.button?.image = NetworkIconRenderer.render(
            up: net.upBytesPerSec, down: net.downBytesPerSec)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
