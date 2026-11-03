import XCTest
@testable import DownloaderCore

final class CommandBuilderTests: XCTestCase {
    private func builder(rate: Int? = nil, cookie: CookieSource = .none) -> YTDLPCommandBuilder {
        YTDLPCommandBuilder(ffmpegLocation: URL(fileURLWithPath: "/x/ffmpeg"),
                            cookieSource: cookie, rateLimitBytesPerSecond: rate)
    }

    func testPreviewArgsUseFlatPlaylistJSON() {
        let args = builder().previewArgs(url: "https://example.com/v")
        XCTAssertTrue(args.contains("--dump-single-json"))
        XCTAssertTrue(args.contains("--flat-playlist"))
        XCTAssertEqual(args.last, "https://example.com/v")
    }

    func testMixURLResolvesVideoOnly() {
        let url = "https://www.youtube.com/watch?v=LKIkHhzSJ3E&list=RDLKIkHhzSJ3E&start_radio=1"
        XCTAssertTrue(builder().previewArgs(url: url).contains("--no-playlist"))
        let dl = builder().downloadArgs(url: url, destination: URL(fileURLWithPath: "/t"))
        XCTAssertTrue(dl.contains("--no-playlist"))
    }

    func testVideoPlusPlaylistURLExpandsPlaylist() {
        let url = "https://www.youtube.com/watch?v=XbZ0qzAz34g&list=PLtAw-mgfCzRySl3ZvhjjPzRnpM4g6Xx-t"
        let args = builder().previewArgs(url: url)
        XCTAssertTrue(args.contains("--yes-playlist"))
        XCTAssertFalse(args.contains("--no-playlist"))
        // Each resolved entry is downloaded on its own.
        XCTAssertTrue(builder().downloadArgs(url: url, destination: URL(fileURLWithPath: "/t"))
            .contains("--no-playlist"))
    }

    func testDownloadArgsCoreFlags() {
        let dest = URL(fileURLWithPath: "/tmp/dl")
        let args = builder().downloadArgs(url: "https://example.com/v", destination: dest)
        XCTAssertTrue(args.contains("--continue"))
        XCTAssertTrue(args.contains("--newline"))
        XCTAssertTrue(adjacent(args, "--paths", dest.path))
        // Directory, so yt-dlp finds both ffmpeg and ffprobe.
        XCTAssertTrue(adjacent(args, "--ffmpeg-location", "/x"))
        XCTAssertTrue(args.contains("--progress-template"))
        XCTAssertFalse(args.contains("--extract-audio"))
    }

    func testBundledDenoPassedAsJSRuntime() {
        let b = YTDLPCommandBuilder(ffmpegLocation: nil, cookieSource: .none, rateLimitBytesPerSecond: nil,
                                    denoLocation: URL(fileURLWithPath: "/x/deno"))
        XCTAssertTrue(adjacent(b.previewArgs(url: "u"), "--js-runtimes", "deno:/x/deno"))
        XCTAssertTrue(adjacent(b.downloadArgs(url: "u", destination: URL(fileURLWithPath: "/t")),
                               "--js-runtimes", "deno:/x/deno"))
        XCTAssertFalse(builder().previewArgs(url: "u").contains("--js-runtimes"))
    }

    func testAudioModeConvertsToMP3At256k() {
        let args = builder().downloadArgs(url: "u", destination: URL(fileURLWithPath: "/t"), mode: .audio)
        XCTAssertTrue(args.contains("--extract-audio"))
        XCTAssertTrue(adjacent(args, "--audio-format", "mp3"))
        XCTAssertTrue(adjacent(args, "--audio-quality", "256K"))
    }

    func testTempDirectoryPassedAsTempPath() {
        let args = builder().downloadArgs(url: "u", destination: URL(fileURLWithPath: "/t"),
                                          tempDirectory: URL(fileURLWithPath: "/tmp/item"))
        XCTAssertTrue(adjacent(args, "--paths", "/t"))
        XCTAssertTrue(args.contains("temp:/tmp/item"))
    }

    func testRateLimitIncludedOnlyWhenSet() {
        let dest = URL(fileURLWithPath: "/tmp/dl")
        let withRate = builder(rate: 1_000_000).downloadArgs(url: "u", destination: dest)
        XCTAssertTrue(adjacent(withRate, "--limit-rate", "1000000"))
        let unlimited = builder(rate: nil).downloadArgs(url: "u", destination: dest)
        XCTAssertFalse(unlimited.contains("--limit-rate"))
    }

    func testCookiesIncludedOnlyWhenBrowserSelected() {
        let dest = URL(fileURLWithPath: "/tmp/dl")
        let withCookie = builder(cookie: .firefox).downloadArgs(url: "u", destination: dest)
        XCTAssertTrue(adjacent(withCookie, "--cookies-from-browser", "firefox"))
        let none = builder(cookie: .none).downloadArgs(url: "u", destination: dest)
        XCTAssertFalse(none.contains("--cookies-from-browser"))
    }

    func testPlaylistItemsPassedThrough() {
        let args = builder().downloadArgs(url: "u", destination: URL(fileURLWithPath: "/t"),
                                          playlistItems: "1,3,5")
        XCTAssertTrue(adjacent(args, "--playlist-items", "1,3,5"))
    }

    private func adjacent(_ args: [String], _ flag: String, _ value: String) -> Bool {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return false }
        return args[i + 1] == value
    }
}
