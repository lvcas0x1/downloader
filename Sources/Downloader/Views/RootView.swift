import SwiftUI

/// The two-tab window shell: Downloads (default) and History (`menubar-app`).
/// Layout follows design/interface.png: the tab switcher (center) and Settings
/// (trailing) live in the title bar toolbar, bridged via `sceneBridgingOptions`.
struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selectedTab: Tab = .downloads
    @State private var showSettings = false

    enum Tab: Hashable { case downloads, history }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            switch selectedTab {
            case .downloads: DownloadsView()
            case .history: HistoryView()
            }
        }
        .font(.system(size: 13))
        .frame(minWidth: 460, minHeight: 540)
        .background(Color(nsColor: .textBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .principal) {
                TabSwitcher(selection: $selectedTab)
            }
            .withoutGlassBackground()
            ToolbarItem(placement: .primaryAction) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.primary)
                        .frame(width: 26, height: 24)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.4)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Settings")
                // The toolbar insets items ~4pt; this brings the trailing margin to 13pt,
                // matching the Resolve button's margin to the window edge.
                .padding(.trailing, 9)
            }
            .withoutGlassBackground()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(environment)
        }
    }
}

private extension ToolbarContent {
    /// macOS 26+ wraps toolbar items in a shared glass capsule; the design uses flat controls.
    @ToolbarContentBuilder
    func withoutGlassBackground() -> some ToolbarContent {
        if #available(macOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

/// Segmented switcher: selected tab filled with the accent color, the other light gray.
private struct TabSwitcher: View {
    @Binding var selection: RootView.Tab

    var body: some View {
        HStack(spacing: 0) {
            segment(.downloads, title: "Downloads", systemImage: "arrow.down.to.line")
            segment(.history, title: "History", systemImage: "clock")
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func segment(_ tab: RootView.Tab, title: String, systemImage: String) -> some View {
        let selected = selection == tab
        return Button { selection = tab } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 11))
                Text(title)
            }
            .font(.system(size: 13))
            .foregroundStyle(selected ? Color.white : Color.primary)
            .frame(width: 110, height: 24)
            .background(selected ? Color.accentColor : Color.secondary.opacity(0.12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
