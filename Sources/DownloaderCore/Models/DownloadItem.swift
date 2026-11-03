import Foundation

/// Lifecycle state of a download (`download-engine`).
public enum DownloadState: String, Equatable, Codable {
    /// Resolved and listed, waiting for the user to choose Download or Audio.
    case ready
    case queued
    case running
    case paused
    case completed
    case failed
    case stopped
}

/// What to download: the full video, or audio only (MP3 256 kbps).
public enum DownloadMode: String, Equatable, Codable {
    case video
    case audio
}

/// Live progress snapshot for an active download.
public struct DownloadProgress: Equatable, Codable {
    public var downloadedBytes: Int?
    public var totalBytes: Int?
    public var speedBytesPerSecond: Double?
    public var etaSeconds: Double?

    public init(
        downloadedBytes: Int? = nil,
        totalBytes: Int? = nil,
        speedBytesPerSecond: Double? = nil,
        etaSeconds: Double? = nil
    ) {
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.speedBytesPerSecond = speedBytesPerSecond
        self.etaSeconds = etaSeconds
    }

    /// Fraction in 0...1 when the total is known; nil for an indeterminate total.
    public var fraction: Double? {
        guard let total = totalBytes, total > 0, let done = downloadedBytes else { return nil }
        return min(1.0, Double(done) / Double(total))
    }
}

/// A unit of download work. One entry == one item (collections enqueue many).
public final class DownloadItem: Identifiable, ObservableObject {
    public let id: UUID
    public let entry: MediaEntry
    public let sourceURL: String
    @Published public var state: DownloadState
    @Published public var mode: DownloadMode
    @Published public var progress: DownloadProgress
    @Published public var failureReason: String?
    /// Resolved destination directory for this item.
    public let destinationDirectory: URL
    /// Per-item directory for yt-dlp intermediary files (`--paths temp:`), so Stop
    /// deletes only this item's partial files, never those of parallel downloads.
    public let tempDirectory: URL

    /// Root for per-item temp directories (overridable so tests stay out of the user's caches).
    public static var tempRoot: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("Downloader/partial", isDirectory: true)
    }()

    public init(
        id: UUID = UUID(),
        entry: MediaEntry,
        sourceURL: String,
        destinationDirectory: URL,
        state: DownloadState = .queued,
        mode: DownloadMode = .video,
        tempDirectory: URL? = nil
    ) {
        self.id = id
        self.entry = entry
        self.sourceURL = sourceURL
        self.destinationDirectory = destinationDirectory
        self.tempDirectory = tempDirectory
            ?? DownloadItem.tempRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        self.state = state
        self.mode = mode
        self.progress = DownloadProgress()
    }
}
