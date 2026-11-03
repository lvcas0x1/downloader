import Foundation

/// Persists finished-download records and enforces the retention bound
/// (`download-history`).
public final class HistoryStore: ObservableObject {
    @Published public private(set) var records: [HistoryRecord] = []

    private let fileURL: URL
    private let fileManager: FileManager
    private var retention: Int

    public init(
        fileURL: URL? = nil,
        retention: Int,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.retention = AppSettings.clampRetention(retention)
        self.fileURL = fileURL ?? HistoryStore.defaultFileURL(fileManager: fileManager)
        load()
    }

    public static func defaultFileURL(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = base.appendingPathComponent("Downloader", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    /// Add a record (newest-first) and trim to the retention bound.
    public func add(_ record: HistoryRecord) {
        records.insert(record, at: 0)
        records = HistoryStore.trim(records, retention: retention)
        persist()
    }

    /// Remove one record (the downloaded file is left untouched).
    public func remove(id: UUID) {
        records.removeAll { $0.id == id }
        persist()
    }

    /// Remove all records.
    public func clearAll() {
        records = []
        persist()
    }

    /// Change the retention bound and trim immediately.
    public func setRetention(_ value: Int) {
        retention = AppSettings.clampRetention(value)
        records = HistoryStore.trim(records, retention: retention)
        persist()
    }

    /// Keep the newest `retention` records, discarding the oldest. 0 keeps none.
    public static func trim(_ records: [HistoryRecord], retention: Int) -> [HistoryRecord] {
        let bound = AppSettings.clampRetention(retention)
        if bound == 0 { return [] }
        let sorted = records.sorted { $0.timestamp > $1.timestamp }
        return Array(sorted.prefix(bound))
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryRecord].self, from: data) else {
            records = []
            return
        }
        records = HistoryStore.trim(decoded, retention: retention)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
