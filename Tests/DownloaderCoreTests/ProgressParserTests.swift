import XCTest
@testable import DownloaderCore

final class ProgressParserTests: XCTestCase {
    let parser = ProgressParser()

    func testParsesCompleteLine() {
        let line = "PROGRESS|524288|1048576|1048576|131072.0|4"
        let p = parser.parse(line: line)
        XCTAssertEqual(p?.downloadedBytes, 524288)
        XCTAssertEqual(p?.totalBytes, 1048576)
        XCTAssertEqual(p?.speedBytesPerSecond, 131072.0)
        XCTAssertEqual(p?.etaSeconds, 4)
        XCTAssertEqual(p?.fraction, 0.5)
    }

    func testFallsBackToTotalEstimate() {
        let line = "PROGRESS|100|NA|400|50.0|NA"
        let p = parser.parse(line: line)
        XCTAssertEqual(p?.totalBytes, 400)
        XCTAssertNil(p?.etaSeconds)
    }

    func testIndeterminateTotalHasNoFraction() {
        let line = "PROGRESS|100|NA|NA|50.0|NA"
        let p = parser.parse(line: line)
        XCTAssertEqual(p?.downloadedBytes, 100)
        XCTAssertNil(p?.totalBytes)
        XCTAssertNil(p?.fraction)
    }

    func testNonProgressLineReturnsNil() {
        XCTAssertNil(parser.parse(line: "[download] Destination: video.mp4"))
        XCTAssertNil(parser.parse(line: "WARNING: something"))
        XCTAssertNil(parser.parse(line: ""))
        XCTAssertNil(parser.parse(line: "PROGRESS|only|three|fields"))
    }
}
