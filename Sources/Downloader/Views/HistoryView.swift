import SwiftUI
import DownloaderCore

/// History tab: per-row re-download (video / audio) and delete, plus bulk clear
/// (`download-history`).
struct HistoryView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var confirmingClear = false

    private var records: [HistoryRecord] {
        environment.historyStore.records.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 0) {
            if records.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock").font(.system(size: 30, weight: .light)).foregroundStyle(.secondary)
                    Text("No history").foregroundStyle(.secondary)
                }
                .padding(.bottom, 56)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(records) { record in
                            row(record).padding(.horizontal, 13)
                            Divider()
                        }
                    }
                }
            }
            Divider()
            HStack {
                Spacer()
                ActionButton(title: "Clear all", systemImage: "trash") { confirmingClear = true }
                    .disabled(records.isEmpty)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
        }
        .confirmationDialog("Clear all history?", isPresented: $confirmingClear) {
            Button("Clear all", role: .destructive) { environment.historyStore.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes all \(records.count) history records.")
        }
    }

    private func row(_ record: HistoryRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: record.outcome == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(record.outcome == .completed ? .green : .red)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title).lineLimit(1)
                Text(subtitle(record)).foregroundStyle(.secondary).lineLimit(1)
                if record.outcome == .failed {
                    Text("Failed — \(record.failureReason ?? "unknown error")")
                        .foregroundStyle(.red).lineLimit(2)
                        .help(record.failureReason ?? "")
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                ActionButton(title: "Download", systemImage: "arrow.down.to.line", style: .primary) {
                    environment.redownload(record, mode: .video)
                }
                ActionButton(title: "Audio", systemImage: "music.note") {
                    environment.redownload(record, mode: .audio)
                }
                // Removes the record only; the downloaded file is kept.
                IconButton(systemImage: "trash", help: "Remove from history") {
                    environment.historyStore.remove(id: record.id)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func subtitle(_ record: HistoryRecord) -> String {
        let mode = record.mode == .audio ? "Audio (MP3)" : "Video"
        let date = record.timestamp.formatted(date: .abbreviated, time: .shortened)
        return "\(mode) · \(date)"
    }
}
