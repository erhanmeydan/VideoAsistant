import Foundation

/// Terminalden çalıştırılabilen komut satırı modları.
///
/// Uygulama normalde pencere olarak açılır; `--selfcheck`, `--smoke` gibi
/// bayraklar verildiğinde arayüz açılmadan konsola çalışır.
enum CLICommand {
    /// Araç, model ve çıktı doğrulamaları.
    case selfcheck(videoPath: String?)

    /// Komut satırı argümanlarından komutu çözer (komut yoksa nil).
    static func parse(arguments: [String]) -> CLICommand? {
        var iterator = arguments.dropFirst().makeIterator()
        var videoPath: String?

        while let argument = iterator.next() {
            switch argument {
            case "--selfcheck":
                videoPath = iterator.next()
                return .selfcheck(videoPath: videoPath)
            default:
                continue
            }
        }
        return nil
    }

    /// Komutu çalıştırır ve çıkış kodunu döndürür (0 = başarılı).
    static func run(_ command: CLICommand) -> Int32 {
        let box = ExitCodeBox()
        let semaphore = DispatchSemaphore(value: 0)

        Task.detached(priority: .userInitiated) {
            let code = await perform(command)
            box.set(code)
            semaphore.signal()
        }

        semaphore.wait()
        return box.value
    }

    private static func perform(_ command: CLICommand) async -> Int32 {
        switch command {
        case .selfcheck(let videoPath):
            return SelfCheck.run(videoPath: videoPath)
        }
    }
}

/// `Task.detached` içinden çıkış kodunu güvenli taşımak için basit bir kutu.
final class ExitCodeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Int32 = 1

    var value: Int32 {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func set(_ code: Int32) {
        lock.lock()
        defer { lock.unlock() }
        stored = code
    }
}
