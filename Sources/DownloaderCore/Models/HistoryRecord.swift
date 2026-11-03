import Foundation

/// A record of a finished download (`download-history`).
public struct HistoryRecord: Identifiable, Equatable, Codable {
    public var id: UUID
    public var sourceURL: String
    public var title: String
    public var outcome: Outcome
    public var destinationPath: String?
    public var failureReason: String?
    public var timestamp: Date
    /// nil for records written before audio-only mode existed (treated as video).
    public var mode: DownloadMode?

    public enum Outcome: String, Codable, Equatable {
        case completed
        case failed
    }

    public init(
        id: UUID = UUID(),
        sourceURL: String,
        title: String,
        outcome: Outcome,
        destinationPath: String? = nil,
        failureReason: String? = nil,
        timestamp: Date = Date(),
        mode: DownloadMode? = nil
    ) {
        self.mode = mode
        self.id = id
        self.sourceURL = sourceURL
        self.title = title
        self.outcome = outcome
        self.destinationPath = destinationPath
        self.failureReason = failureReason
        self.timestamp = timestamp
    }
}
