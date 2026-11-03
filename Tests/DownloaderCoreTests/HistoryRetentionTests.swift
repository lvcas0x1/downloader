import XCTest
@testable import DownloaderCore

final class HistoryRetentionTests: XCTestCase {
    private func makeRecords(_ n: Int) -> [HistoryRecord] {
        (0..<n).map { i in
            HistoryRecord(sourceURL: "u\(i)", title: "t\(i)", outcome: .completed,
                          timestamp: Date(timeIntervalSince1970: Double(i)))
        }
    }

    func testTrimKeepsNewest() {
        let trimmed = HistoryStore.trim(makeRecords(10), retention: 3)
        XCTAssertEqual(trimmed.count, 3)
        XCTAssertEqual(trimmed.map(\.title), ["t9", "t8", "t7"])
    }

    func testRetentionZeroKeepsNothing() {
        XCTAssertTrue(HistoryStore.trim(makeRecords(5), retention: 0).isEmpty)
    }

    func testAddTrimsToBound() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hist-\(UUID().uuidString).json")
        let store = HistoryStore(fileURL: url, retention: 2)
        for i in 0..<5 {
            store.add(HistoryRecord(sourceURL: "u\(i)", title: "t\(i)", outcome: .completed,
                                    timestamp: Date(timeIntervalSince1970: Double(i))))
        }
        XCTAssertEqual(store.records.count, 2)
        try? FileManager.default.removeItem(at: url)
    }

    func testLoweringRetentionTrimsImmediately() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hist-\(UUID().uuidString).json")
        let store = HistoryStore(fileURL: url, retention: 100)
        for i in 0..<10 {
            store.add(HistoryRecord(sourceURL: "u\(i)", title: "t\(i)", outcome: .completed,
                                    timestamp: Date(timeIntervalSince1970: Double(i))))
        }
        XCTAssertEqual(store.records.count, 10)
        store.setRetention(4)
        XCTAssertEqual(store.records.count, 4)
        try? FileManager.default.removeItem(at: url)
    }

    func testPersistenceRoundTrip() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hist-\(UUID().uuidString).json")
        let store = HistoryStore(fileURL: url, retention: 100)
        store.add(HistoryRecord(sourceURL: "u", title: "kept", outcome: .failed, failureReason: "x"))
        let reloaded = HistoryStore(fileURL: url, retention: 100)
        XCTAssertEqual(reloaded.records.first?.title, "kept")
        XCTAssertEqual(reloaded.records.first?.outcome, .failed)
        try? FileManager.default.removeItem(at: url)
    }
}
