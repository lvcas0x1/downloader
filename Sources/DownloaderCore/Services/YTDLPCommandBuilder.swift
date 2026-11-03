import Foundation

/// Builds yt-dlp argument vectors for preview and download operations.
///
/// Flags verified against the official yt-dlp README (master):
/// `-J/--dump-single-json`, `-j/--dump-json`, `--flat-playlist`, `-s/--simulate`,
/// `-I/--playlist-items`, `--newline`, `--progress-template`, `--progress-delta`,
/// `--limit-rate`, `-c/--continue`, `-P/--paths`, `-o/--output`,
/// `--ffmpeg-location`, `--cookies-from-browser`.
public struct YTDLPCommandBuilder {
    /// Delimited machine-readable progress line template. Parsed by `ProgressParser`.
    public static let progressTemplate =
        "download:" + ProgressParser.marker +
        "|%(progress.downloaded_bytes)s|%(progress.total_bytes)s" +
        "|%(progress.total_bytes_estimate)s|%(progress.speed)s|%(progress.eta)s"

    /// Default output template; yt-dlp substitutes title/ext.
    public static let outputTemplate = "%(title)s [%(id)s].%(ext)s"

    public let ffmpegLocation: URL?
    public let cookieSource: CookieSource
    public let rateLimitBytesPerSecond: Int?
    /// Bundled Deno; without a JS runtime YouTube formats can be missing or fail (HTTP 403).
    public let denoLocation: URL?

    public init(
        ffmpegLocation: URL?,
        cookieSource: CookieSource,
        rateLimitBytesPerSecond: Int?,
        denoLocation: URL? = nil
    ) {
        self.ffmpegLocation = ffmpegLocation
        self.cookieSource = cookieSource
        self.rateLimitBytesPerSecond = rateLimitBytesPerSecond
        self.denoLocation = denoLocation
    }

    /// True for a YouTube Mix (`list=RD…`): an auto-generated, effectively endless list.
    /// The RD-prefix convention is not officially documented; yt-dlp only lists `RD`
    /// among YouTube playlist ID prefixes (`_PLAYLIST_ID_RE`).
    public static func isMixPlaylist(url: String) -> Bool {
        let list = URLComponents(string: url)?.queryItems?.first { $0.name == "list" }?.value
        return list?.hasPrefix("RD") ?? false
    }

    /// Args to resolve a preview without downloading.
    /// Uses `--flat-playlist` so collections list entries cheaply. A URL naming both a
    /// video and a playlist expands the playlist (`--yes-playlist`), except for a Mix,
    /// which resolves to the video only (`--no-playlist`).
    public func previewArgs(url: String) -> [String] {
        let playlistFlag = YTDLPCommandBuilder.isMixPlaylist(url: url) ? "--no-playlist" : "--yes-playlist"
        var args = ["--dump-single-json", "--flat-playlist", playlistFlag, "--no-warnings", url]
        args.append(contentsOf: jsRuntimeArgs())
        args.append(contentsOf: cookieArgs())
        return args
    }

    /// Audio-only conversion: MP3 at 256 kbps. `-x` needs ffmpeg and ffprobe.
    public static let audioArgs = ["--extract-audio", "--audio-format", "mp3", "--audio-quality", "256K"]

    /// Args to download a single entry into `destination`.
    public func downloadArgs(
        url: String,
        destination: URL,
        mode: DownloadMode = .video,
        tempDirectory: URL? = nil,
        playlistItems: String? = nil
    ) -> [String] {
        var args: [String] = []
        args += ["--continue", "--no-overwrites"]
        args += ["--newline", "--progress-delta", "0.5"]
        args += ["--progress-template", YTDLPCommandBuilder.progressTemplate]
        args += ["--paths", destination.path]
        if let temp = tempDirectory {
            args += ["--paths", "temp:" + temp.path]
        }
        args += ["--output", YTDLPCommandBuilder.outputTemplate]
        if let ffmpeg = ffmpegLocation {
            // The containing directory, so yt-dlp finds both ffmpeg and ffprobe.
            args += ["--ffmpeg-location", ffmpeg.deletingLastPathComponent().path]
        }
        if mode == .audio {
            args += YTDLPCommandBuilder.audioArgs
        }
        if let rate = rateLimitBytesPerSecond, rate > 0 {
            args += ["--limit-rate", String(rate)]
        }
        if let items = playlistItems {
            args += ["--playlist-items", items]
        } else {
            args.append("--no-playlist")
        }
        args += jsRuntimeArgs()
        args += cookieArgs()
        args.append(url)
        return args
    }

    private func jsRuntimeArgs() -> [String] {
        guard let deno = denoLocation else { return [] }
        return ["--js-runtimes", "deno:" + deno.path]
    }

    private func cookieArgs() -> [String] {
        guard let token = cookieSource.ytdlpToken else { return [] }
        return ["--cookies-from-browser", token]
    }
}
