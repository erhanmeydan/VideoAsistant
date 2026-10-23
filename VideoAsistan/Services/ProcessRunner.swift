import Foundation

/// Harici araçları (ffmpeg, whisper-cli) çalıştırmak için yardımcı.
///
/// Hem stdout hem stderr sürekli boşaltılır; aksi hâlde boru tamponu dolar ve
/// alt süreç takılır.
enum ProcessRunner {
    struct Result {
        let exitCode: Int32
        let standardOutput: String
        let standardError: String
        var succeeded: Bool { exitCode == 0 }
    }

    enum RunnerError: LocalizedError {
        case launchFailed(String, underlying: Error)
        case failed(exitCode: Int32, errorTail: String)

        var errorDescription: String? {
            switch self {
            case .launchFailed(let tool, let underlying):
                return "\(tool) çalıştırılamadı: \(underlying.localizedDescription)"
            case .failed(let exitCode, let errorTail):
                return "İşlem başarısız (çıkış kodu \(exitCode)). \(errorTail)"
            }
        }
    }

    /// Verilen komutu çalıştırır, çıktı satırlarını geri çağrıya iletir.
    static func run(
        executable: URL,
        arguments: [String],
        toolName: String? = nil,
        onOutputLine: ((String) -> Void)? = nil,
        onErrorLine: ((String) -> Void)? = nil
    ) async throws -> Result {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let collector = OutputCollector()
        let outputLines = LineSplitter { line in onOutputLine?(line) }
        let errorLines = LineSplitter { line in onErrorLine?(line) }

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = ResumeGuard()

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                collector.appendStandardOutput(data)
                outputLines.feed(data)
            }

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                collector.appendStandardError(data)
                errorLines.feed(data)
            }

            process.terminationHandler = { finished in
                // Kalan veriyi oku.
                let remainingOutput = (try? outputPipe.fileHandleForReading.readToEnd()) ?? Data()
                let remainingError = (try? errorPipe.fileHandleForReading.readToEnd()) ?? Data()
                if !remainingOutput.isEmpty {
                    collector.appendStandardOutput(remainingOutput)
                    outputLines.feed(remainingOutput)
                }
                if !remainingError.isEmpty {
                    collector.appendStandardError(remainingError)
                    errorLines.feed(remainingError)
                }
                outputLines.flush()
                errorLines.flush()

                let result = Result(
                    exitCode: finished.terminationStatus,
                    standardOutput: collector.standardOutputString,
                    standardError: collector.standardErrorString
                )
                if hasResumed.claim() {
                    continuation.resume(returning: result)
                }
            }

            do {
                try process.run()
            } catch {
                if hasResumed.claim() {
                    continuation.resume(throwing: RunnerError.launchFailed(toolName ?? executable.lastPathComponent, underlying: error))
                }
            }
        }
    }
}

/// Alt süreç çıktısını güvenli biçimde toplar.
final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var output = Data()
    private var error = Data()

    func appendStandardOutput(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        output.append(data)
    }

    func appendStandardError(_ data: Data) {
        lock.lock(); defer { lock.unlock() }
        error.append(data)
    }

    var standardOutputString: String {
        lock.lock(); defer { lock.unlock() }
        return String(data: output, encoding: .utf8) ?? ""
    }

    var standardErrorString: String {
        lock.lock(); defer { lock.unlock() }
        return String(data: error, encoding: .utf8) ?? ""
    }
}

/// Gelen veriyi satırlara böler.
final class LineSplitter: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private let handler: (String) -> Void

    init(handler: @escaping (String) -> Void) {
        self.handler = handler
    }

    func feed(_ data: Data) {
        lock.lock()
        buffer.append(data)
        var lines: [String] = []
        while let index = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<index]
            buffer.removeSubrange(buffer.startIndex...index)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line.trimmingCharacters(in: .newlines))
            }
        }
        lock.unlock()

        for line in lines where !line.isEmpty {
            handler(line)
        }
    }

    func flush() {
        lock.lock()
        let rest = buffer
        buffer.removeAll()
        lock.unlock()
        if let line = String(data: rest, encoding: .utf8), !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            handler(line.trimmingCharacters(in: .newlines))
        }
    }
}

/// `withCheckedThrowingContinuation` için tek seferlik devam garantisi.
final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false

    /// Devam ettirildiğinde true döner, aksi hâlde false.
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}
