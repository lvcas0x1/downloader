import Foundation

enum Format {
    static func bytes(_ value: Int?) -> String {
        guard let value else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }

    static func speed(_ bytesPerSecond: Double?) -> String {
        guard let bps = bytesPerSecond, bps > 0 else { return "—" }
        let s = ByteCountFormatter.string(fromByteCount: Int64(bps), countStyle: .file)
        return "\(s)/s"
    }

    static func duration(_ seconds: Double?) -> String {
        guard let seconds, seconds > 0 else { return "" }
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func percent(_ fraction: Double?) -> String {
        guard let fraction else { return "" }
        return String(format: "%.0f%%", fraction * 100)
    }
}
