import SwiftUI

/// Menubar-only app entry. No WindowGroup: the status item owns the window
/// (`menubar-app`).
@main
struct DownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
