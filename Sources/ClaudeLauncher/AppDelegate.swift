import AppKit
import HotKey

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var panel: FloatingPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Claude Launcher")
            button.action = #selector(togglePanel)
            button.target = self
        }

        // Register Option+Space
        hotKey = HotKey(key: .space, modifiers: [.option])
        hotKey?.keyDownHandler = { [weak self] in
            self?.togglePanel()
        }
    }

    @objc private func togglePanel() {
        if let existing = panel, existing.isVisible {
            existing.close()
            panel = nil
            return
        }

        let p = FloatingPanel()
        p.center()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = p
    }
}
