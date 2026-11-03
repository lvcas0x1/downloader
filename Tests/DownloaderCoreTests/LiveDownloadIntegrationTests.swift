import XCTest
@testable import DownloaderCore

/// Real end-to-end checks that execute the bundled yt-dlp against the network.
/// Skipped unless DOWNLOADER_RUN_INTEGRATION=1 (needs network + Resources/bin/yt-dlp).
///
///   DOWNLOADER_RUN_INTEGRATION=1 xcodebuild test \
///     -scheme DownloaderCore -destination 'platform=macOS' \
///     -only-testing:DownloaderCoreTests/LiveDownloadIntegrationTests
final class LiveDownloadIntegrationTests: XCTestCase {
    /// Small, stable, direct HTTPS media file (W3C-hosted Sintel trailer).
    private let testURL = "https://media.w3.org/2010/05/sintel/trailer.mp4"

    private func repoResourceDir() -> URL {
        // Tests/DownloaderCoreTests/<file> -> repo root is three levels up.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
    }

    private func requireIntegration() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["DOWNLOADER_RUN_INTEGRATION"] == "1",
            "Set DOWNLOADER_RUN_INTEGRATION=1 to run live download integration tests."
        )
    }

    /// 4.1 / 8.2: a real download writes a file to the destination.
    func testRealDownloadWritesFile() throws {
        try requireIntegration()
        let locator = BinaryLocator(resourceDirectory: repoResourceDir())
        let ytdlp = try locator.ytdlpURL()
        let ffmpeg = try? locator.ffmpegURL()

        let fm = FileManager.default
        let dest = fm.temporaryDirectory.appendingPathComponent("dltest-\(UUID().uuidString)")
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dest) }

        let builder = YTDLPCommandBuilder(
            ffmpegLocation: ffmpeg, cookieSource: .none, rateLimitBytesPerSecond: nil)
        let entry = MediaEntry(id: "t", title: "trailer", url: testURL)
        let item = DownloadItem(entry: entry, sourceURL: testURL, destinationDirectory: dest)
        let task = DownloadTask(item: item, ytdlpURL: ytdlp, commandBuilder: builder)

        let finished = expectation(description: "terminal state")
        task.onTerminal = { _ in finished.fulfill() }
        task.start()
        wait(for: [finished], timeout: 180)

        XCTAssertEqual(item.state, .completed, "reason: \(item.failureReason ?? "-")")
        let files = try fm.contentsOfDirectory(atPath: dest.path).filter { !$0.hasPrefix(".") }
        XCTAssertFalse(files.isEmpty, "expected at least one downloaded file")
    }

    /// 5.5: a plain HTTPS link previews with a resolvable title/entry.
    func testRealPreviewResolves() throws {
        try requireIntegration()
        let locator = BinaryLocator(resourceDirectory: repoResourceDir())
        let builder = YTDLPCommandBuilder(
            ffmpegLocation: nil, cookieSource: .none, rateLimitBytesPerSecond: nil)
        let resolver = PreviewResolver(binaryLocator: locator, commandBuilder: builder)

        let done = expectation(description: "preview resolved")
        var resolved: MediaPreview?
        _ = resolver.resolve(url: testURL) { result in
            if case .success(let p) = result { resolved = p }
            done.fulfill()
        }
        wait(for: [done], timeout: 120)
        XCTAssertNotNil(resolved)
        XCTAssertFalse(resolved?.entries.isEmpty ?? true)
    }
}
