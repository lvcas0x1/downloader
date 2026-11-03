import SwiftUI
import DownloaderCore

/// One resolved entry in the Downloads list. Controls follow the lifecycle:
/// ready → [Download][Audio], running → [Pause][Stop], paused → [Resume][Stop]
/// (`download-intake`, `download-engine`).
struct DownloadRowView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject var item: DownloadItem

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.entry.title).lineLimit(1)
                detail
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) { controls }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var detail: some View {
        switch item.state {
        case .ready:
            secondary(metadata)
        case .queued:
            secondary("\(modeLabel) · Waiting…")
        case .running, .paused:
            if let fraction = item.progress.fraction {
                ProgressView(value: fraction).controlSize(.small)
            } else {
                ProgressView(value: nil as Double?).controlSize(.small)
            }
            secondary(progressText)
        case .failed:
            Text("Failed — \(item.failureReason ?? "unknown error")")
                .foregroundStyle(.red).lineLimit(2)
        case .completed, .stopped:
            EmptyView() // removed from the list on these transitions
        }
    }

    @ViewBuilder
    private var controls: some View {
        let queue = environment.queue
        switch item.state {
        case .ready, .failed:
            ActionButton(title: "Download", systemImage: "arrow.down.to.line", style: .primary) {
                queue.start(item, mode: .video)
            }
            ActionButton(title: "Audio", systemImage: "music.note") {
                queue.start(item, mode: .audio)
            }
            IconButton(systemImage: "xmark", help: "Remove from list") { queue.remove(item) }
        case .queued:
            ActionButton(title: "Pause", systemImage: "pause") {}.disabled(true)
            ActionButton(title: "Stop", systemImage: "stop") { queue.stop(item) }
        case .running:
            ActionButton(title: "Pause", systemImage: "pause") { queue.pause(item) }
            ActionButton(title: "Stop", systemImage: "stop") { queue.stop(item) }
        case .paused:
            ActionButton(title: "Resume", systemImage: "play") { queue.resume(item) }
            ActionButton(title: "Stop", systemImage: "stop") { queue.stop(item) }
        case .completed, .stopped:
            EmptyView()
        }
    }

    private func secondary(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).lineLimit(1)
    }

    private var modeLabel: String { item.mode == .audio ? "Audio (MP3)" : "Video" }

    private var metadata: String {
        let parts = [Format.duration(item.entry.durationSeconds), item.entry.uploader ?? ""]
            .filter { !$0.isEmpty }
        return parts.isEmpty ? (URL(string: item.entry.url)?.host ?? item.entry.url) : parts.joined(separator: " · ")
    }

    private var progressText: String {
        let p = item.progress
        let amount = p.fraction.map { Format.percent($0) } ?? Format.bytes(p.downloadedBytes)
        if item.state == .paused { return "\(modeLabel) · Paused · \(amount)" }
        return "\(modeLabel) · \(amount) · \(Format.speed(p.speedBytesPerSecond))"
    }
}
