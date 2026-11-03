import XCTest
@testable import DownloaderCore

final class PreviewAndCleanupTests: XCTestCase {
    // MARK: Preview parsing

    func testParsesSingleVideo() throws {
        let json = """
        {"id":"abc","title":"My Video","ext":"mp4","duration":123.0,
         "uploader":"Someone","webpage_url":"https://x/v","filesize":1000}
        """.data(using: .utf8)!
        let preview = try PreviewResolver.parse(jsonData: json, sourceURL: "https://x/v")
        guard case .single(let entry) = preview else { return XCTFail("expected single") }
        XCTAssertEqual(entry.title, "My Video")
        XCTAssertEqual(entry.ext, "mp4")
        XCTAssertEqual(entry.durationSeconds, 123.0)
    }

    func testParsesPlaylist() throws {
        let json = """
        {"_type":"playlist","title":"My List","entries":[
          {"id":"1","title":"E1","url":"https://x/1","duration":10},
          {"id":"2","title":"E2","url":"https://x/2","duration":20}]}
        """.data(using: .utf8)!
        let preview = try PreviewResolver.parse(jsonData: json, sourceURL: "https://x/list")
        guard case .collection(let title, let entries) = preview else { return XCTFail("expected collection") }
        XCTAssertEqual(title, "My List")
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.map(\.title), ["E1", "E2"])
    }

    func testURLValidation() {
        XCTAssertTrue(PreviewResolver.isSupportedURL("https://example.com/x"))
        XCTAssertTrue(PreviewResolver.isSupportedURL("http://example.com"))
        XCTAssertFalse(PreviewResolver.isSupportedURL("ftp://example.com"))
        XCTAssertFalse(PreviewResolver.isSupportedURL("not a url"))
        XCTAssertFalse(PreviewResolver.isSupportedURL("magnet:?xt=urn"))
    }

}
