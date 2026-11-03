import Foundation

/// Persists `AppSettings` in UserDefaults and exposes it for the UI
/// (`app-settings`).
public final class SettingsStore: ObservableObject {
    @Published public var settings: AppSettings {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let key = "com.lvcas0x1.downloader.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
    }

    /// Set retention only if within the valid range; returns false if rejected.
    @discardableResult
    public func setRetention(_ value: Int) -> Bool {
        guard AppSettings.isValidRetention(value) else { return false }
        settings.historyRetention = value
        return true
    }

    public func setConcurrency(_ value: Int) {
        settings.maxConcurrentDownloads = AppSettings.clampConcurrency(value)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
