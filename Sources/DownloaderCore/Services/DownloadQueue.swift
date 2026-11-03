import Foundation
import Combine

/// Schedules downloads, honoring the configured concurrency limit, and records
/// terminal outcomes into history (`download-engine`).
public final class DownloadQueue: ObservableObject {
    @Published public private(set) var items: [DownloadItem] = [] {
        didSet { syncItemObservers() }
    }

    private var tasks: [UUID: DownloadTask] = [:]
    /// Relays each item's changes so views summarizing the queue (e.g. "N ready") refresh.
    private var itemObservers: [UUID: AnyCancellable] = [:]
    private let binaryLocator: BinaryLocator
    private let runner: ProcessRunning
    private let settingsProvider: () -> AppSettings
    private let historyStore: HistoryStore

    public init(
        binaryLocator: BinaryLocator,
        historyStore: HistoryStore,
        settingsProvider: @escaping () -> AppSettings,
        runner: ProcessRunning = SystemProcessRunner()
    ) {
        self.binaryLocator = binaryLocator
        self.historyStore = historyStore
        self.settingsProvider = settingsProvider
        self.runner = runner
    }

    private var maxConcurrent: Int { settingsProvider().maxConcurrentDownloads }
    private var runningCount: Int { items.filter { $0.state == .running }.count }

    /// List resolved entries as `.ready` rows without starting them; rows accumulate
    /// across resolutions (`download-intake`).
    public func add(entries: [MediaEntry], sourceURL: String) {
        let destination = settingsProvider().resolvedDestination
        for entry in entries {
            items.append(DownloadItem(
                entry: entry, sourceURL: sourceURL, destinationDirectory: destination, state: .ready))
        }
    }

    /// Enqueue and start one item per entry (`download-engine`: collections enqueue each entry).
    public func enqueue(entries: [MediaEntry], sourceURL: String, mode: DownloadMode = .video) {
        let destination = settingsProvider().resolvedDestination
        for entry in entries {
            let item = DownloadItem(
                entry: entry, sourceURL: sourceURL, destinationDirectory: destination, mode: mode)
            items.append(item)
        }
        schedule()
    }

    /// Start a ready (or failed, to retry) item in the chosen mode.
    public func start(_ item: DownloadItem, mode: DownloadMode) {
        guard item.state == .ready || item.state == .failed else { return }
        item.mode = mode
        item.failureReason = nil
        item.progress = DownloadProgress()
        item.state = .queued
        schedule()
    }

    /// Remove a row that is not downloading (ready or failed).
    public func remove(_ item: DownloadItem) {
        guard item.state == .ready || item.state == .failed else { return }
        try? FileManager.default.removeItem(at: item.tempDirectory) // a failed item may hold partials
        items.removeAll { $0.id == item.id }
    }

    /// Start queued items until the concurrency limit is reached.
    public func schedule() {
        guard runningCount < maxConcurrent else { return }
        let queued = items.filter { $0.state == .queued }
        for item in queued {
            if runningCount >= maxConcurrent { break }
            startTask(for: item)
        }
    }

    private func startTask(for item: DownloadItem) {
        let ytdlp: URL
        do {
            ytdlp = try binaryLocator.ytdlpURL()
        } catch {
            item.failureReason = error.localizedDescription
            item.state = .failed
            moveToHistory(item)
            return
        }
        let settings = settingsProvider()
        let ffmpeg = try? binaryLocator.ffmpegURL()
        let builder = YTDLPCommandBuilder(
            ffmpegLocation: ffmpeg,
            cookieSource: settings.cookieSource,
            rateLimitBytesPerSecond: settings.rateLimitBytesPerSecond,
            denoLocation: try? binaryLocator.denoURL()
        )
        let task = DownloadTask(item: item, ytdlpURL: ytdlp, commandBuilder: builder, runner: runner)
        task.onTerminal = { [weak self] finished in
            guard let self else { return }
            self.tasks[finished.item.id] = nil
            if finished.item.state == .completed || finished.item.state == .failed {
                self.moveToHistory(finished.item)
            }
            self.schedule()
        }
        tasks[item.id] = task
        task.start()
    }

    public func pause(_ item: DownloadItem) { tasks[item.id]?.pause(); schedule() }
    public func resume(_ item: DownloadItem) {
        if let task = tasks[item.id] { task.resume() } else { startTask(for: item) }
    }

    /// Stop deletes partial files (via the task) and removes the row from the list.
    public func stop(_ item: DownloadItem) {
        if let task = tasks[item.id] {
            task.stop()
        } else {
            item.state = .stopped
        }
        tasks[item.id] = nil
        items.removeAll { $0.id == item.id }
        schedule()
    }

    /// Remove finished (completed/failed/stopped) items from the active list.
    public func clearFinished() {
        items.removeAll { [.completed, .failed, .stopped].contains($0.state) }
    }

    private func syncItemObservers() {
        let ids = Set(items.map(\.id))
        itemObservers = itemObservers.filter { ids.contains($0.key) }
        for item in items where itemObservers[item.id] == nil {
            itemObservers[item.id] = item.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
        }
    }

    /// Completed and failed downloads both leave the Downloads list and become history
    /// records (re-downloadable from there). Records keep the entry's own URL (not a
    /// playlist URL) so re-download fetches just that item.
    private func moveToHistory(_ item: DownloadItem) {
        let outcome: HistoryRecord.Outcome = item.state == .completed ? .completed : .failed
        historyStore.add(HistoryRecord(
            sourceURL: item.entry.url, title: item.entry.title, outcome: outcome,
            destinationPath: item.destinationDirectory.path,
            failureReason: outcome == .failed ? item.failureReason : nil, mode: item.mode))
        if outcome == .failed {
            try? FileManager.default.removeItem(at: item.tempDirectory) // no retry from this row
        }
        items.removeAll { $0.id == item.id }
    }
}
