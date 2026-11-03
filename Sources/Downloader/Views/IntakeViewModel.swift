import Foundation
import DownloaderCore

/// Drives URL input and resolution (`download-intake`). A resolved URL's entries
/// are appended to the Downloads list as ready rows; the field then clears for the
/// next URL. All mutations occur on the main thread.
final class IntakeViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case invalid(String)
        case resolving
        case failed(String)
    }

    @Published var urlText: String = ""
    @Published var phase: Phase = .idle

    private let environment: AppEnvironment
    private var pending: Cancellable?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func submit() {
        // Return fires both the field's onCommit and the default-action Resolve button.
        guard phase != .resolving else { return }
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PreviewResolver.isSupportedURL(url) else {
            phase = .invalid("Enter a valid http:// or https:// URL.")
            return
        }
        phase = .resolving
        let resolver = environment.makePreviewResolver()
        pending = resolver.resolve(url: url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.pending = nil
                switch result {
                case .success(let preview):
                    self.environment.queue.add(entries: preview.entries, sourceURL: url)
                    self.urlText = ""
                    self.phase = .idle
                case .failure(let error):
                    self.phase = .failed(error.errorDescription ?? "Resolution failed.")
                }
            }
        }
    }

    func cancelResolution() {
        pending?.cancel()
        pending = nil
        phase = .idle
    }
}
