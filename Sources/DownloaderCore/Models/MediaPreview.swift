import Foundation

/// A single resolvable media entry shown in the preview (`download-intake`).
public struct MediaEntry: Identifiable, Equatable, Codable {
    public var id: String
    public var title: String
    public var url: String
    public var durationSeconds: Double?
    public var uploader: String?
    public var thumbnailURL: String?
    public var ext: String?
    public var filesizeBytes: Int?

    public init(
        id: String,
        title: String,
        url: String,
        durationSeconds: Double? = nil,
        uploader: String? = nil,
        thumbnailURL: String? = nil,
        ext: String? = nil,
        filesizeBytes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.durationSeconds = durationSeconds
        self.uploader = uploader
        self.thumbnailURL = thumbnailURL
        self.ext = ext
        self.filesizeBytes = filesizeBytes
    }
}

/// The result of resolving a submitted URL before any download begins.
public enum MediaPreview: Equatable {
    /// A single media item.
    case single(MediaEntry)
    /// A playlist / watchlist / channel / collection with one or more entries.
    case collection(title: String, entries: [MediaEntry])

    public var entries: [MediaEntry] {
        switch self {
        case .single(let entry): return [entry]
        case .collection(_, let entries): return entries
        }
    }

    public var isCollection: Bool {
        if case .collection = self { return true }
        return false
    }
}
