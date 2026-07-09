import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = SystemMonitor.shared
    private var statusController: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController(monitor: monitor)
        monitor.start()
    }
}
