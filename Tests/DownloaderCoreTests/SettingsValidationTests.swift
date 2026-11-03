import XCTest
@testable import DownloaderCore

final class SettingsValidationTests: XCTestCase {
    func testDefaults() {
        let s = AppSettings()
        XCTAssertNil(s.rateLimitBytesPerSecond, "rate limit defaults to unlimited")
        XCTAssertEqual(s.maxConcurrentDownloads, AppSettings.defaultConcurrency)
        XCTAssertEqual(s.cookieSource, .none)
        XCTAssertNil(s.destinationDirectory)
    }

    func testDefaultDestinationIsDownloads() {
        let s = AppSettings()
        XCTAssertEqual(s.resolvedDestination.lastPathComponent, "Downloads")
    }

    func testConcurrencyIsAtLeastOne() {
        XCTAssertEqual(AppSettings.clampConcurrency(0), 1)
        XCTAssertEqual(AppSettings.clampConcurrency(-5), 1)
        XCTAssertEqual(AppSettings.clampConcurrency(4), 4)
        XCTAssertEqual(AppSettings(maxConcurrentDownloads: 0).maxConcurrentDownloads, 1)
    }

    func testRetentionValidationAndClamping() {
        XCTAssertTrue(AppSettings.isValidRetention(0))
        XCTAssertTrue(AppSettings.isValidRetention(1000))
        XCTAssertFalse(AppSettings.isValidRetention(-1))
        XCTAssertFalse(AppSettings.isValidRetention(1001))
        XCTAssertEqual(AppSettings.clampRetention(-10), 0)
        XCTAssertEqual(AppSettings.clampRetention(5000), 1000)
        XCTAssertEqual(AppSettings.clampRetention(500), 500)
    }

    func testCookieToken() {
        XCTAssertNil(CookieSource.none.ytdlpToken)
        XCTAssertEqual(CookieSource.chrome.ytdlpToken, "chrome")
    }

    func testSettingsStoreRejectsOutOfRangeRetention() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        XCTAssertFalse(store.setRetention(2000))
        XCTAssertTrue(store.setRetention(300))
        XCTAssertEqual(store.settings.historyRetention, 300)
    }
}
