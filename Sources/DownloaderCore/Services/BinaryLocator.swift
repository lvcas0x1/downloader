import Foundation

/// Locates the bundled yt-dlp and ffmpeg binaries (`download-engine`).
///
/// Binaries are shipped inside the app bundle under `Contents/Resources/bin`.
/// The app must never depend on a system-installed yt-dlp or ffmpeg.
public struct BinaryLocator {
    public enum BinaryError: LocalizedError, Equatable {
        case missing(name: String)
        case notExecutable(path: String)

        public var errorDescription: String? {
            switch self {
            case .missing(let name):
                return "Required bundled component “\(name)” was not found in the app. Reinstall the app."
            case .notExecutable(let path):
                return "Bundled component at \(path) is not executable."
            }
        }
    }

    private let resourceDirectory: URL?
    private let fileManager: FileManager

    public init(bundle: Bundle = .main, fileManager: FileManager = .default) {
        self.resourceDirectory = bundle.resourceURL
        self.fileManager = fileManager
    }

    /// Resolve binaries under an explicit directory (used in tests).
    public init(resourceDirectory: URL, fileManager: FileManager = .default) {
        self.resourceDirectory = resourceDirectory
        self.fileManager = fileManager
    }

    public func url(forBinary name: String) throws -> URL {
        guard let resources = resourceDirectory else {
            throw BinaryError.missing(name: name)
        }
        let candidate = resources.appendingPathComponent("bin/\(name)")
        guard fileManager.fileExists(atPath: candidate.path) else {
            throw BinaryError.missing(name: name)
        }
        guard fileManager.isExecutableFile(atPath: candidate.path) else {
            throw BinaryError.notExecutable(path: candidate.path)
        }
        return candidate
    }

    public func ytdlpURL() throws -> URL { try url(forBinary: "yt-dlp") }
    public func ffmpegURL() throws -> URL { try url(forBinary: "ffmpeg") }
    /// JavaScript runtime yt-dlp needs to solve YouTube challenges (yt-dlp wiki: EJS).
    public func denoURL() throws -> URL { try url(forBinary: "deno") }
}
