import Foundation

/// A handle that can cancel an in-flight process.
public protocol Cancellable: AnyObject {
    func cancel()
}

public final class NoopCancellable: Cancellable {
    public init() {}
    public func cancel() {}
}

/// Captured output of a completed process run.
public struct ProcessOutput {
    public let terminationStatus: Int32
    public let stdoutData: Data
    public let stderrData: Data
}

public enum ProcessRunError: LocalizedError {
    case launchFailed(String)
    case nonZeroExit(status: Int32, stderr: String)

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let msg): return "Failed to launch: \(msg)"
        case .nonZeroExit(let status, let stderr):
            return stderr.isEmpty ? "Process exited with status \(status)." : stderr
        }
    }
}

/// Abstraction over launching a subprocess so the logic is testable.
public protocol ProcessRunning {
    /// Run `executable` with `arguments`. `onLine` receives each stdout line as
    /// it arrives (for progress). `completion` fires on termination.
    @discardableResult
    func run(
        executable: URL,
        arguments: [String],
        onLine: ((String) -> Void)?,
        completion: @escaping (Result<ProcessOutput, ProcessRunError>) -> Void
    ) -> Cancellable
}

/// Real implementation backed by `Foundation.Process`.
public final class SystemProcessRunner: ProcessRunning {
    public init() {}

    public final class Handle: Cancellable {
        fileprivate let process: Process
        private let lock = NSLock()
        private var cancelled = false
        fileprivate init(process: Process) { self.process = process }
        public func cancel() {
            lock.lock(); defer { lock.unlock() }
            cancelled = true
            if process.isRunning { process.terminate() }
        }
        public var wasCancelled: Bool {
            lock.lock(); defer { lock.unlock() }
            return cancelled
        }
    }

    @discardableResult
    public func run(
        executable: URL,
        arguments: [String],
        onLine: ((String) -> Void)?,
        completion: @escaping (Result<ProcessOutput, ProcessRunError>) -> Void
    ) -> Cancellable {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let handle = Handle(process: process)
        let stdoutBuffer = LineBuffer()
        var stdoutData = Data()
        let dataLock = NSLock()

        stdoutPipe.fileHandleForReading.readabilityHandler = { fh in
            let chunk = fh.availableData
            guard !chunk.isEmpty else { return }
            dataLock.lock(); stdoutData.append(chunk); dataLock.unlock()
            if let onLine {
                for line in stdoutBuffer.append(chunk) { onLine(line) }
            }
        }

        process.terminationHandler = { proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            let remaining = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            if !remaining.isEmpty {
                dataLock.lock(); stdoutData.append(remaining); dataLock.unlock()
            }
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            dataLock.lock(); let out = stdoutData; dataLock.unlock()
            let output = ProcessOutput(
                terminationStatus: proc.terminationStatus,
                stdoutData: out,
                stderrData: stderrData
            )
            if handle.wasCancelled {
                completion(.failure(.nonZeroExit(status: proc.terminationStatus, stderr: "Cancelled")))
            } else if proc.terminationStatus == 0 {
                completion(.success(output))
            } else {
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                completion(.failure(.nonZeroExit(status: proc.terminationStatus, stderr: stderr)))
            }
        }

        do {
            try process.run()
        } catch {
            completion(.failure(.launchFailed(error.localizedDescription)))
        }
        return handle
    }
}

/// Accumulates bytes and yields complete newline-delimited lines.
final class LineBuffer {
    private var buffer = Data()
    func append(_ data: Data) -> [String] {
        buffer.append(data)
        var lines: [String] = []
        while let nl = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            if let s = String(data: lineData, encoding: .utf8) {
                lines.append(s.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
            }
        }
        return lines
    }
}
