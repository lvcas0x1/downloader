import Foundation

/// User-configurable preferences that govern downloads.
/// Validation here backs the `app-settings` capability.
public struct AppSettings: Equatable, Codable {
    /// Destination directory for completed files. `nil` means "use the default".
    public var destinationDirectory: URL?
    /// Maximum download rate in bytes per second. `nil` means unlimited.
    public var rateLimitBytesPerSecond: Int?
    /// Maximum number of parallel downloads. Always >= 1.
    public var maxConcurrentDownloads: Int
    /// History retention count, clamped to `retentionRange`.
    public var historyRetention: Int
    /// Browser whose cookies are used for authenticated content.
    public var cookieSource: CookieSource

    public static let retentionRange: ClosedRange<Int> = 0...1000
    public static let defaultConcurrency = 3

    public init(
        destinationDirectory: URL? = nil,
        rateLimitBytesPerSecond: Int? = nil,
        maxConcurrentDownloads: Int = AppSettings.defaultConcurrency,
        historyRetention: Int = 200,
        cookieSource: CookieSource = .none
    ) {
        self.destinationDirectory = destinationDirectory
        self.rateLimitBytesPerSecond = rateLimitBytesPerSecond
        self.maxConcurrentDownloads = AppSettings.clampConcurrency(maxConcurrentDownloads)
        self.historyRetention = AppSettings.clampRetention(historyRetention)
        self.cookieSource = cookieSource
    }

    /// Resolved destination: the configured folder, or the user's Downloads folder.
    public var resolvedDestination: URL {
        destinationDirectory ?? AppSettings.defaultDownloadsDirectory
    }

    public static var defaultDownloadsDirectory: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    /// Clamp retention to the valid 0...1000 range.
    public static func clampRetention(_ value: Int) -> Int {
        min(max(value, retentionRange.lowerBound), retentionRange.upperBound)
    }

    /// Reject values outside the valid retention range.
    public static func isValidRetention(_ value: Int) -> Bool {
        retentionRange.contains(value)
    }

    /// Concurrency must be at least 1.
    public static func clampConcurrency(_ value: Int) -> Int {
        max(value, 1)
    }
}

/// Browser used as the cookie source for `--cookies-from-browser`.
public enum CookieSource: String, Codable, CaseIterable, Equatable {
    case none
    case safari
    case chrome
    case firefox
    case edge
    case brave

    /// The yt-dlp browser token, or nil when cookies are disabled.
    public var ytdlpToken: String? {
        self == .none ? nil : rawValue
    }

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .safari: return "Safari"
        case .chrome: return "Chrome"
        case .firefox: return "Firefox"
        case .edge: return "Edge"
        case .brave: return "Brave"
        }
    }
}
