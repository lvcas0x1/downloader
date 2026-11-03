import Foundation

/// Parses yt-dlp `--progress-template` lines into `DownloadProgress`.
///
/// Expected line (fields may be "NA"):
/// `PROGRESS|downloaded|total|total_estimate|speed|eta`
/// Lines that are not progress lines (warnings, post-processing) parse to nil.
public struct ProgressParser {
    public static let marker = "PROGRESS"

    public init() {}

    public func parse(line: String) -> DownloadProgress? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(ProgressParser.marker + "|") else { return nil }
        let parts = trimmed.components(separatedBy: "|")
        // marker + 5 fields
        guard parts.count == 6 else { return nil }

        let downloaded = Self.intValue(parts[1])
        let total = Self.intValue(parts[2]) ?? Self.intValue(parts[3]) // fall back to estimate
        let speed = Self.doubleValue(parts[4])
        let eta = Self.doubleValue(parts[5])

        return DownloadProgress(
            downloadedBytes: downloaded,
            totalBytes: total,
            speedBytesPerSecond: speed,
            etaSeconds: eta
        )
    }

    private static func intValue(_ s: String) -> Int? {
        let v = s.trimmingCharacters(in: .whitespaces)
        if v.isEmpty || v == "NA" || v == "None" { return nil }
        if let i = Int(v) { return i }
        if let d = Double(v) { return Int(d) }
        return nil
    }

    private static func doubleValue(_ s: String) -> Double? {
        let v = s.trimmingCharacters(in: .whitespaces)
        if v.isEmpty || v == "NA" || v == "None" { return nil }
        return Double(v)
    }
}
