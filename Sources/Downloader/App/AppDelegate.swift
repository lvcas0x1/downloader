import AppKit
import SwiftUI

/// Owns the menubar status item and the single toggled window (`menubar-app`).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    let environment = AppEnvironment()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Agent app: no Dock icon, no app-switcher entry (also set via LSUIElement).
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()
        buildWindow()
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Downloader")
        button.action = #selector(statusItemClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func buildWindow() {
        let root = RootView().environmentObject(environment)
        let hosting = NSHostingController(rootView: root)
        // SwiftUI `.toolbar` items populate the window toolbar (title bar row).
        hosting.sceneBridgingOptions = [.toolbars]
        let window = NSWindow(contentViewController: hosting)
        window.title = "Downloader"
        // Unified frame (design/interface.png): one surface, toolbar merged into the title bar.
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .unifiedCompact
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .line
        window.backgroundColor = .textBackgroundColor
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // 546x720 overall per the design; content excludes the ~54pt title bar row.
        window.setContentSize(NSSize(width: 546, height: 666))
        window.center()
        self.window = window
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleWindow()
        }
    }

    private func toggleWindow() {
        if window.isVisible && window.isKeyWindow {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Downloader", action: #selector(openWindow), keyEquivalent: "")
        let quit = NSMenuItem(title: "Quit Downloader", action: #selector(quit), keyEquivalent: "q")
        [open, quit].forEach { $0.target = self }
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // restore left-click toggle behavior
    }

    @objc private func openWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        // Stop in-progress downloads (deletes partial files) before terminating.
        for item in environment.queue.items where item.state == .running || item.state == .paused {
            environment.queue.stop(item)
        }
        NSApp.terminate(nil)
    }
}
