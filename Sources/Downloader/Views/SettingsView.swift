import SwiftUI
import AppKit
import DownloaderCore

/// Edits persisted preferences (`app-settings`).
struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var rateLimitEnabled = false
    @State private var rateLimitMBps = 2.0
    @State private var retentionText = ""

    private var store: SettingsStore { environment.settingsStore }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings").font(.system(size: 13))

            destinationRow
            Divider()
            concurrencyRow
            rateRow
            Divider()
            retentionRow
            cookieRow

            Spacer()
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .font(.system(size: 13))
        .padding(20)
        .frame(width: 440, height: 440)
        .onAppear(perform: syncFromStore)
    }

    private var destinationRow: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Destination folder").font(.system(size: 13))
                Text(store.settings.resolvedDestination.path)
                    .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button("Choose…", action: chooseDestination)
        }
    }

    private var concurrencyRow: some View {
        Stepper(value: Binding(
            get: { store.settings.maxConcurrentDownloads },
            set: { store.setConcurrency($0) }
        ), in: 1...10) {
            Text("Parallel downloads: \(store.settings.maxConcurrentDownloads)")
        }
    }

    private var rateRow: some View {
        VStack(alignment: .leading) {
            Toggle("Limit download speed", isOn: $rateLimitEnabled)
                .onChange(of: rateLimitEnabled) { _, _ in applyRate() }
            if rateLimitEnabled {
                HStack {
                    Slider(value: $rateLimitMBps, in: 0.1...50, step: 0.1) { _ in applyRate() }
                    Text(String(format: "%.1f MB/s", rateLimitMBps)).monospacedDigit()
                }
            } else {
                Text("Unlimited").font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
    }

    private var retentionRow: some View {
        HStack {
            Text("History retention (0–1000)")
            Spacer()
            TextField("200", text: $retentionText)
                .frame(width: 70)
                .onSubmit(applyRetention)
            Button("Set", action: applyRetention)
        }
    }

    private var cookieRow: some View {
        Picker("Cookie source", selection: Binding(
            get: { store.settings.cookieSource },
            set: { store.settings.cookieSource = $0 }
        )) {
            ForEach(CookieSource.allCases, id: \.self) { source in
                Text(source.displayName).tag(source)
            }
        }
    }

    private func syncFromStore() {
        if let rate = store.settings.rateLimitBytesPerSecond {
            rateLimitEnabled = true
            rateLimitMBps = Double(rate) / 1_000_000.0
        } else {
            rateLimitEnabled = false
        }
        retentionText = String(store.settings.historyRetention)
    }

    private func applyRate() {
        store.settings.rateLimitBytesPerSecond = rateLimitEnabled ? Int(rateLimitMBps * 1_000_000) : nil
    }

    private func applyRetention() {
        if let value = Int(retentionText), store.setRetention(value) {
            retentionText = String(value)
        } else {
            // Rejected: restore the last valid value.
            retentionText = String(store.settings.historyRetention)
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.settings.destinationDirectory = url
        }
    }
}
