import AppKit
import SwiftUI
import Combine

// Owns the NSStatusItem: keeps the menu bar icon in sync with the latest
// network speeds, shows the SwiftUI dashboard in a popover on left click,
// and a small Quit context menu on right click (the standard convention for
// menu bar utilities, so the dashboard itself doesn't need a Quit button).
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let monitor: SystemMonitor
    private let popover = NSPopover()
    private var cancellable: AnyCancellable?

    init(monitor: SystemMonitor) {
        self.monitor = monitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover.behavior = .transient
        let hosting = NSHostingController(rootView: DashboardView().environmentObject(monitor))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
        }

        cancellable = monitor.$snapshot
            .map(\.network)
            .receive(on: RunLoop.main)
            .sink { [weak self] net in self?.updateIcon(net) }

        updateIcon(monitor.snapshot.network)
    }

    private func updateIcon(_ net: NetworkSample) {
        statusItem.button?.image = NetworkIconRenderer.render(
            up: net.upBytesPerSec, down: net.downBytesPerSec)
    }

    @objc private func handleClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Activate the app so the popover's window becomes key -- without
            // this, the panel can appear but its SwiftUI controls won't
            // respond to clicks, since an .accessory app isn't frontmost by
            // default and a non-key window doesn't route control clicks the
            // same way.
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit top", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        // Popped up directly via NSMenu.popUp rather than statusItem.menu --
        // assigning statusItem.menu makes NSStatusItem show that menu on
        // EVERY click (left included) and bypasses target/action entirely,
        // which would break left-click-to-open-dashboard.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
