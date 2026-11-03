import XCTest
@testable import DownloaderCore

/// A ProcessRunning that records launches and completes on demand.
final class FakeProcessRunner: ProcessRunning {
    struct Launch { let executable: URL; let arguments: [String] }
    private(set) var launches: [Launch] = []
    private var completions: [(Result<ProcessOutput, ProcessRunError>) -> Void] = []
    private var lineHandlers: [((String) -> Void)?] = []

    func run(
        executable: URL,
        arguments: [String],
        onLine: ((String) -> Void)?,
        completion: @escaping (Result<ProcessOutput, ProcessRunError>) -> Void
    ) -> Cancellable {
        launches.append(Launch(executable: executable, arguments: arguments))
        lineHandlers.append(onLine)
        completions.append(completion)
        return NoopCancellable()
    }

    func emitLine(_ line: String, at index: Int) { lineHandlers[index]?(line) }
    func complete(at index: Int, success: Bool) {
        let output = ProcessOutput(terminationStatus: success ? 0 : 1, stdoutData: Data(), stderrData: Data())
        completions[index](success ? .success(output) : .failure(.nonZeroExit(status: 1, stderr: "boom")))
    }
}

final class DownloadEngineTests: XCTestCase {
    private var tempBundle: URL!

    override func setUpWithError() throws {
        tempBundle = FileManager.default.temporaryDirectory
            .appendingPathComponent("bundle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempBundle.appendingPathComponent("bin"), withIntermediateDirectories: true)
        DownloadItem.tempRoot = tempBundle.appendingPathComponent("partial")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempBundle)
    }

    private func installBinaries() throws {
        for name in ["yt-dlp", "ffmpeg"] {
            let url = tempBundle.appendingPathComponent("bin/\(name)")
            try Data("#!/bin/sh\n".utf8).write(to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }

    private func makeQueue(runner: FakeProcessRunner, concurrency: Int, history: HistoryStore) -> DownloadQueue {
        var settings = AppSettings(maxConcurrentDownloads: concurrency)
        settings.destinationDirectory = tempBundle
        return DownloadQueue(
            binaryLocator: BinaryLocator(resourceDirectory: tempBundle),
            historyStore: history,
            settingsProvider: { settings },
            runner: runner
        )
    }

    private func entries(_ n: Int) -> [MediaEntry] {
        (0..<n).map { MediaEntry(id: "\($0)", title: "E\($0)", url: "https://x/\($0)") }
    }

    private func makeHistory() -> HistoryStore {
        HistoryStore(fileURL: tempBundle.appendingPathComponent("h.json"), retention: 100)
    }

    func testConcurrencyLimitQueuesExcess() throws {
        try installBinaries()
        let runner = FakeProcessRunner()
        let queue = makeQueue(runner: runner, concurrency: 2, history: makeHistory())

        queue.enqueue(entries: entries(3), sourceURL: "https://x/list")
        XCTAssertEqual(queue.items.filter { $0.state == .running }.count, 2)
        XCTAssertEqual(queue.items.filter { $0.state == .queued }.count, 1)
        XCTAssertEqual(runner.launches.count, 2)

        // Finishing one frees a slot for the queued item.
        runner.complete(at: 0, success: true)
        XCTAssertEqual(queue.items.filter { $0.state == .running }.count, 2)
        XCTAssertEqual(runner.launches.count, 3)
    }

    func testEachEntryBecomesItsOwnItem() throws {
        try installBinaries()
        let queue = makeQueue(runner: FakeProcessRunner(), concurrency: 5, history: makeHistory())
        queue.enqueue(entries: entries(4), sourceURL: "https://x/list")
        XCTAssertEqual(queue.items.count, 4)
    }

    func testPauseThenResumeRelaunches() throws {
        try installBinaries()
        let runner = FakeProcessRunner()
        let queue = makeQueue(runner: runner, concurrency: 1, history: makeHistory())
        queue.enqueue(entries: entries(1), sourceURL: "https://x/0")
        let item = queue.items[0]
        XCTAssertEqual(item.state, .running)

        queue.pause(item)
        XCTAssertEqual(item.state, .paused)

        queue.resume(item)
        XCTAssertEqual(item.state, .running)
        XCTAssertEqual(runner.launches.count, 2, "resume relaunches yt-dlp (relies on --continue)")
        XCTAssertTrue(runner.launches.allSatisfy { $0.arguments.contains("--continue") })
    }

    func testCompletedAndFailedMoveToHistory() throws {
        try installBinaries()
        let runner = FakeProcessRunner()
        let history = makeHistory()
        let queue = makeQueue(runner: runner, concurrency: 2, history: history)
        queue.enqueue(entries: entries(2), sourceURL: "https://x/list")

        runner.complete(at: 0, success: true)
        runner.complete(at: 1, success: false)

        XCTAssertTrue(queue.items.isEmpty, "both leave the Downloads list")
        XCTAssertEqual(history.records.count, 2)
        XCTAssertEqual(history.records.filter { $0.outcome == .completed }.count, 1)
        let failed = history.records.first { $0.outcome == .failed }
        XCTAssertNotNil(failed?.failureReason)
    }

    func testAddedEntriesWaitAsReadyUntilStarted() throws {
        try installBinaries()
        let runner = FakeProcessRunner()
        let queue = makeQueue(runner: runner, concurrency: 2, history: makeHistory())
        queue.add(entries: entries(2), sourceURL: "https://x/list")
        queue.add(entries: entries(1), sourceURL: "https://x/0") // rows accumulate
        XCTAssertEqual(queue.items.count, 3)
        XCTAssertTrue(queue.items.allSatisfy { $0.state == .ready })
        XCTAssertEqual(runner.launches.count, 0)

        queue.start(queue.items[1], mode: .audio)
        XCTAssertEqual(queue.items[1].state, .running)
        XCTAssertEqual(runner.launches.count, 1)
        XCTAssertTrue(runner.launches[0].arguments.contains("--extract-audio"))
    }

    func testQueuePublishesItemStateChanges() throws {
        try installBinaries()
        let queue = makeQueue(runner: FakeProcessRunner(), concurrency: 1, history: makeHistory())
        queue.add(entries: entries(1), sourceURL: "https://x/0")
        var changes = 0
        let sub = queue.objectWillChange.sink { changes += 1 }
        defer { sub.cancel() }
        queue.items[0].state = .failed
        XCTAssertGreaterThan(changes, 0)
    }

    func testStopDeletesOwnPartialsAndRemovesRow() throws {
        try installBinaries()
        let runner = FakeProcessRunner()
        let queue = makeQueue(runner: runner, concurrency: 2, history: makeHistory())
        queue.enqueue(entries: entries(2), sourceURL: "https://x/list")
        let (stopped, other) = (queue.items[0], queue.items[1])
        let partial = stopped.tempDirectory.appendingPathComponent("a.mp4.part")
        let otherPartial = other.tempDirectory.appendingPathComponent("b.mp4.part")
        try Data("x".utf8).write(to: partial)
        try Data("x".utf8).write(to: otherPartial)
        defer { queue.stop(other) }

        queue.stop(stopped)
        XCTAssertFalse(FileManager.default.fileExists(atPath: partial.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: otherPartial.path),
                      "a parallel download's partial file must survive")
        XCTAssertEqual(queue.items.map(\.id), [other.id])
    }

    func testHistoryRecordKeepsEntryURLAndMode() throws {
        try installBinaries()
        let runner = FakeProcessRunner()
        let history = makeHistory()
        let queue = makeQueue(runner: runner, concurrency: 1, history: history)
        queue.add(entries: entries(1), sourceURL: "https://x/list")
        queue.start(queue.items[0], mode: .audio)
        runner.complete(at: 0, success: true)

        XCTAssertEqual(history.records.first?.sourceURL, "https://x/0")
        XCTAssertEqual(history.records.first?.mode, .audio)
        history.remove(id: history.records[0].id)
        XCTAssertTrue(history.records.isEmpty)
    }

    func testMissingBinaryFailsDownload() throws {
        // Do NOT install binaries: the locator cannot find yt-dlp.
        let history = makeHistory()
        let queue = makeQueue(runner: FakeProcessRunner(), concurrency: 1, history: history)
        queue.enqueue(entries: entries(1), sourceURL: "https://x/0")

        XCTAssertTrue(queue.items.isEmpty)
        XCTAssertEqual(history.records.first?.outcome, .failed)
        XCTAssertNotNil(history.records.first?.failureReason)
    }

    func testProgressLineUpdatesItem() throws {
        try installBinaries()
        let runner = FakeProcessRunner()
        let queue = makeQueue(runner: runner, concurrency: 1, history: makeHistory())
        queue.enqueue(entries: entries(1), sourceURL: "https://x/0")

        runner.emitLine("PROGRESS|500|1000|1000|250.0|2", at: 0)
        XCTAssertEqual(queue.items[0].progress.downloadedBytes, 500)
        XCTAssertEqual(queue.items[0].progress.fraction, 0.5)
        XCTAssertEqual(queue.items[0].progress.speedBytesPerSecond, 250.0)
    }
}
