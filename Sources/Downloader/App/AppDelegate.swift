import AppKit
import Sparkle
import SwiftUI

/// Owns the menubar status item and the single toggled window (`menubar-app`).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    let environment = AppEnvironment()
    /// Sparkle updater: checks the appcast (Info.plist `SUFeedURL`) automatically and on demand.
    private lazy var updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Agent app: no Dock icon, no app-switcher entry (also set via LSUIElement).
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()
        buildWindow()
        _ = updater
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
        let update = NSMenuItem(title: "Update", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        update.target = updater
        menu.addItem(update)
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

// MARK: Update reminders

/// Gentle reminders for a menu-bar app: while an update alert is shown, the app appears in the Dock
/// (badged when the check was scheduled) so the alert is not lost behind other windows.
/// https://sparkle-project.org/documentation/gentle-reminders/
extension AppDelegate: SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        NSApp.setActivationPolicy(.regular)
        if !state.userInitiated {
            NSApp.dockTile.badgeLabel = "1"
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        NSApp.dockTile.badgeLabel = ""
    }

    func standardUserDriverWillFinishUpdateSession() {
        NSApp.setActivationPolicy(.accessory)
    }
}
