import Foundation

/// Drives a single download through its lifecycle via a yt-dlp subprocess
/// (`download-engine`: Start/Pause/Resume/Stop, progress, failure).
public final class DownloadTask {
    public let item: DownloadItem

    private let ytdlpURL: URL
    private let commandBuilder: YTDLPCommandBuilder
    private let runner: ProcessRunning
    private let fileManager: FileManager
    private let parser = ProgressParser()

    private var handle: Cancellable?
    /// Called when the task reaches a terminal state (completed/failed/stopped).
    public var onTerminal: ((DownloadTask) -> Void)?

    public init(
        item: DownloadItem,
        ytdlpURL: URL,
        commandBuilder: YTDLPCommandBuilder,
        runner: ProcessRunning = SystemProcessRunner(),
        fileManager: FileManager = .default
    ) {
        self.item = item
        self.ytdlpURL = ytdlpURL
        self.commandBuilder = commandBuilder
        self.runner = runner
        self.fileManager = fileManager
    }

    public func start() {
        guard item.state == .queued || item.state == .paused else { return }
        setState(.running)
        try? fileManager.createDirectory(at: item.tempDirectory, withIntermediateDirectories: true)
        let args = commandBuilder.downloadArgs(
            url: item.entry.url, destination: item.destinationDirectory,
            mode: item.mode, tempDirectory: item.tempDirectory)
        handle = runner.run(executable: ytdlpURL, arguments: args, onLine: { [weak self] line in
            guard let self, let progress = self.parser.parse(line: line) else { return }
            self.onMain { self.item.progress = progress }
        }, completion: { [weak self] result in
            guard let self else { return }
            self.onMain {
                guard self.item.state == .running else { return } // pause/stop already handled
                switch result {
                case .success:
                    self.removeTempDirectory() // final files were already moved to the destination
                    self.setState(.completed)
                case .failure(let error):
                    // Keep partial files so a retry can continue.
                    self.item.failureReason = error.localizedDescription
                    self.setState(.failed)
                }
                self.onTerminal?(self)
            }
        })
    }

    /// Pause keeps partial files so the download can resume.
    public func pause() {
        guard item.state == .running else { return }
        setState(.paused)
        handle?.cancel()
        handle = nil
    }

    public func resume() {
        guard item.state == .paused else { return }
        start() // --continue resumes from the retained partial file
    }

    /// Stop cancels and deletes this item's in-progress/partial files.
    public func stop() {
        setState(.stopped)
        handle?.cancel()
        handle = nil
        removeTempDirectory()
        onMain { self.onTerminal?(self) }
    }

    private func removeTempDirectory() {
        try? fileManager.removeItem(at: item.tempDirectory)
    }

    private func setState(_ state: DownloadState) {
        onMain { self.item.state = state }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}
