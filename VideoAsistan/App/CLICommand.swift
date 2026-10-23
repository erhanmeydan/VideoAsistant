import Foundation

/// Terminalden çalıştırılabilen komut satırı modları.
///
/// Uygulama normalde pencere olarak açılır; `--selfcheck`, `--smoke` gibi
/// bayraklar verildiğinde arayüz açılmadan konsola çalışır.
enum CLICommand {
    /// Araç, model ve çıktı doğrulamaları.
    case selfcheck(videoPath: String?)
    /// MiniMax API bağlantı testi.
    case apiTest(prompt: String)
    /// Ses çıkarma ve yerel yazıya çevirme testi.
    case transcribe(videoPath: String)

    /// Komut satırı argümanlarından komutu çözer (komut yoksa nil).
    static func parse(arguments: [String]) -> CLICommand? {
        var iterator = arguments.dropFirst().makeIterator()
        var videoPath: String?

        while let argument = iterator.next() {
            switch argument {
            case "--selfcheck":
                videoPath = iterator.next()
                return .selfcheck(videoPath: videoPath)
            case "--transcribe":
                guard let path = iterator.next() else {
                    print("HATA: --transcribe için video yolu gerekli. Kullanım: --transcribe <video.mp4>")
                    return nil
                }
                return .transcribe(videoPath: path)
            case "--apitest":
                var prompt = "Kısa bir Türkçe tanıtım cümlesi yaz."
                if let next = iterator.next(), !next.hasPrefix("--") {
                    prompt = next
                }
                return .apiTest(prompt: prompt)
            default:
                continue
            }
        }
        return nil
    }

    /// Komutu çalıştırır ve çıkış kodunu döndürür (0 = başarılı).
    ///
    /// Ana iş parçacığı bekleme sırasında boş bırakılmaz; döngü çalıştırılarak
    /// URLSession geri çağrılarının ve bağlantı izlemenin ilerlemesi sağlanır.
    static func run(_ command: CLICommand) -> Int32 {
        let box = ExitCodeBox()
        Task.detached(priority: .userInitiated) {
            let code = await perform(command)
            box.set(code)
        }

        while !box.isFinished {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return box.value
    }

    private static func perform(_ command: CLICommand) async -> Int32 {
        switch command {
        case .selfcheck(let videoPath):
            return SelfCheck.run(videoPath: videoPath)
        case .apiTest(let prompt):
            return await ApiTestRunner.run(prompt: prompt)
        case .transcribe(let videoPath):
            return await TranscribeRunner.run(videoPath: videoPath)
        }
    }
}

/// `Task.detached` içinden çıkış kodunu güvenli taşımak için basit bir kutu.
final class ExitCodeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Int32 = 1
    private var finished = false

    var value: Int32 {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return finished
    }

    func set(_ code: Int32) {
        lock.lock()
        defer { lock.unlock() }
        stored = code
        finished = true
    }
}
