import SwiftUI
import DownloaderCore

/// URL intake + the accumulating list of resolved, active, and queued items
/// (`download-intake`, `download-engine`).
struct DownloadsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        DownloadsContent(intake: environment.intake, queue: environment.queue)
            .environmentObject(environment)
    }
}

private struct DownloadsContent: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var intake: IntakeViewModel
    @ObservedObject var queue: DownloadQueue

    var body: some View {
        VStack(spacing: 0) {
            inputBar
            statusLine
            Divider()
            if queue.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "link").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("Paste a URL…", text: $intake.urlText, onCommit: intake.submit)
                    .textFieldStyle(.plain)
                Button { intake.urlText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.4)))

            if intake.phase == .resolving {
                ProgressView().controlSize(.small)
                Button("Cancel", action: intake.cancelResolution)
                    .buttonStyle(.plain)
                    .frame(height: 28)
            } else {
                Button(action: intake.submit) {
                    HStack(spacing: 5) { Image(systemName: "play").font(.system(size: 10)); Text("Resolve") }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 3))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 13)
    }

    /// Inline validation / resolution errors; the list below stays visible.
    @ViewBuilder
    private var statusLine: some View {
        switch intake.phase {
        case .invalid(let message), .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)
                .padding(.bottom, 10)
        default:
            EmptyView()
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(queue.items) { item in
                        DownloadRowView(item: item).padding(.horizontal, 13)
                        Divider()
                    }
                }
            }
            bulkBar
        }
    }

    /// Bulk actions for multi-entry (playlist/collection) results.
    @ViewBuilder
    private var bulkBar: some View {
        let ready = queue.items.filter { $0.state == .ready }
        if ready.count > 1 {
            Divider()
            HStack(spacing: 6) {
                Spacer()
                Text("\(ready.count) ready").foregroundStyle(.secondary)
                ActionButton(title: "Download all", systemImage: "arrow.down.to.line", style: .primary) {
                    ready.forEach { queue.start($0, mode: .video) }
                }
                ActionButton(title: "Audio all", systemImage: "music.note") {
                    ready.forEach { queue.start($0, mode: .audio) }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 30, weight: .light)).foregroundStyle(.secondary)
            Text("No downloads yet").foregroundStyle(.secondary)
        }
        .padding()
        // Center on the whole window (as in the design), not just the area below the input bar.
        .padding(.bottom, 110)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
