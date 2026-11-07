import Foundation

/// Resolves a submitted URL into a `MediaPreview` by running yt-dlp with
/// `--dump-single-json --flat-playlist` (`download-intake`).
public final class PreviewResolver {
    public enum PreviewError: LocalizedError {
        case invalidURL
        case resolutionFailed(String)
        case binaryError(Error)

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Enter a valid http:// or https:// URL."
            case .resolutionFailed(let reason): return reason
            case .binaryError(let error): return error.localizedDescription
            }
        }
    }

    private let binaryLocator: BinaryLocator
    private let commandBuilder: YTDLPCommandBuilder
    private let runner: ProcessRunning

    public init(
        binaryLocator: BinaryLocator,
        commandBuilder: YTDLPCommandBuilder,
        runner: ProcessRunning = SystemProcessRunner()
    ) {
        self.binaryLocator = binaryLocator
        self.commandBuilder = commandBuilder
        self.runner = runner
    }

    /// Validates that a string is an http(s) URL (`download-intake`).
    public static func isSupportedURL(_ string: String) -> Bool {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && (url.host?.isEmpty == false)
    }

    /// Runs yt-dlp and returns a cancellable handle; the completion delivers the preview.
    public func resolve(
        url: String,
        completion: @escaping (Result<MediaPreview, PreviewError>) -> Void
    ) -> Cancellable {
        guard PreviewResolver.isSupportedURL(url) else {
            completion(.failure(.invalidURL))
            return NoopCancellable()
        }
        let ytdlp: URL
        do {
            ytdlp = try binaryLocator.ytdlpURL()
        } catch {
            completion(.failure(.binaryError(error)))
            return NoopCancellable()
        }
        let args = commandBuilder.previewArgs(url: url)
        return runner.run(executable: ytdlp, arguments: args, onLine: nil) { result in
            switch result {
            case .failure(let error):
                completion(.failure(.resolutionFailed(error.localizedDescription)))
            case .success(let output):
                do {
                    let preview = try PreviewResolver.parse(jsonData: output.stdoutData, sourceURL: url)
                    completion(.success(preview))
                } catch {
                    let stderr = String(data: output.stderrData, encoding: .utf8) ?? ""
                    completion(.failure(.resolutionFailed(stderr.isEmpty ? error.localizedDescription : stderr)))
                }
            }
        }
    }

    /// Parses yt-dlp `--dump-single-json` output into a `MediaPreview`.
    public static func parse(jsonData: Data, sourceURL: String) throws -> MediaPreview {
        guard let root = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw PreviewError.resolutionFailed("Could not read preview data.")
        }
        let type = root["_type"] as? String
        if type == "playlist" || root["entries"] != nil {
            let rawEntries = root["entries"] as? [[String: Any]] ?? []
            let title = (root["title"] as? String) ?? "Playlist"
            let entries = rawEntries.enumerated().map { index, dict in
                parseEntry(dict, fallbackID: "\(index)", fallbackURL: sourceURL, collectionTitle: title)
            }
            return .collection(title: title, entries: entries)
        } else {
            return .single(parseEntry(root, fallbackID: "0", fallbackURL: sourceURL))
        }
    }

    /// Title for a flat entry that has only a `?p=N` URL, as Bilibili multi-part videos do.
    private static func partTitle(collectionTitle: String, url: String?) -> String? {
        guard let url,
              let part = URLComponents(string: url)?.queryItems?.first(where: { $0.name == "p" })?.value
        else { return nil }
        return "\(collectionTitle) (P\(part))"
    }

    private static func parseEntry(
        _ dict: [String: Any],
        fallbackID: String,
        fallbackURL: String,
        collectionTitle: String? = nil
    ) -> MediaEntry {
        let id = (dict["id"] as? String) ?? fallbackID
        let rawURL = dict["url"] as? String
        let title = (dict["title"] as? String)
            ?? collectionTitle.flatMap { partTitle(collectionTitle: $0, url: rawURL) }
            ?? rawURL ?? "Untitled"
        let url = (dict["webpage_url"] as? String) ?? (dict["url"] as? String) ?? fallbackURL
        let duration = (dict["duration"] as? Double) ?? (dict["duration"] as? NSNumber)?.doubleValue
        let uploader = dict["uploader"] as? String
        let thumb = dict["thumbnail"] as? String
        let ext = dict["ext"] as? String
        let filesize = (dict["filesize"] as? Int) ?? (dict["filesize_approx"] as? Int)
            ?? (dict["filesize"] as? NSNumber)?.intValue
        return MediaEntry(
            id: id, title: title, url: url, durationSeconds: duration,
            uploader: uploader, thumbnailURL: thumb, ext: ext, filesizeBytes: filesize
        )
    }
}
