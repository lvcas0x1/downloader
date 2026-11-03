import Foundation
import Combine
import DownloaderCore

/// Wires the stores and the download queue together and keeps history
/// retention in sync with settings.
final class AppEnvironment: ObservableObject {
    let settingsStore: SettingsStore
    let historyStore: HistoryStore
    let queue: DownloadQueue
    let binaryLocator = BinaryLocator()
    /// Shared intake/preview view model, wired to this environment.
    private(set) lazy var intake: IntakeViewModel = IntakeViewModel(environment: self)

    private var cancellables = Set<AnyCancellable>()

    init() {
        let settingsStore = SettingsStore()
        let history = HistoryStore(retention: settingsStore.settings.historyRetention)
        let queue = DownloadQueue(
            binaryLocator: BinaryLocator(),
            historyStore: history,
            settingsProvider: { settingsStore.settings }
        )
        self.settingsStore = settingsStore
        self.historyStore = history
        self.queue = queue

        // Downloads-list rows do not survive relaunch, so leftover partial files
        // (e.g. from failed items at quit) are garbage.
        try? FileManager.default.removeItem(at: DownloadItem.tempRoot)

        // Keep history retention and queue scheduling in sync with settings changes.
        settingsStore.$settings
            .map(\.historyRetention)
            .removeDuplicates()
            .sink { [weak history] retention in history?.setRetention(retention) }
            .store(in: &cancellables)

        settingsStore.$settings
            .map(\.maxConcurrentDownloads)
            .removeDuplicates()
            .sink { [weak queue] _ in queue?.schedule() }
            .store(in: &cancellables)

        // Forward child object changes so views observing AppEnvironment refresh.
        queue.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        history.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        settingsStore.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// Move a history record back to Downloads and start it immediately (`download-history`).
    func redownload(_ record: HistoryRecord, mode: DownloadMode) {
        historyStore.remove(id: record.id)
        let entry = MediaEntry(id: record.id.uuidString, title: record.title, url: record.sourceURL)
        queue.enqueue(entries: [entry], sourceURL: record.sourceURL, mode: mode)
    }

    /// A preview resolver configured from the current settings.
    func makePreviewResolver() -> PreviewResolver {
        let settings = settingsStore.settings
        let ffmpeg = try? binaryLocator.ffmpegURL()
        let builder = YTDLPCommandBuilder(
            ffmpegLocation: ffmpeg,
            cookieSource: settings.cookieSource,
            rateLimitBytesPerSecond: settings.rateLimitBytesPerSecond,
            denoLocation: try? binaryLocator.denoURL()
        )
        return PreviewResolver(binaryLocator: binaryLocator, commandBuilder: builder)
    }
}
