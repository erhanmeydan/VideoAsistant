import Foundation

/// Uygulamanın dosya sistemi yolları.
///
/// Whisper modeli ve geçici çalışma dosyaları kullanıcının Application Support
/// klasöründe tutulur; proje klasörüne hiçbir şey yazılmaz.
enum AppPaths {
    static let applicationDirectoryName = "VideoAsistant"

    static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent(applicationDirectoryName, isDirectory: true)
    }

    /// Whisper model dosyalarının arandığı birincil klasör.
    static var modelsDirectory: URL {
        applicationSupport.appendingPathComponent("models", isDirectory: true)
    }

    /// Ara adımların (ses, transkript) yazıldığı geçici çalışma klasörü.
    static var workDirectory: URL {
        applicationSupport.appendingPathComponent("work", isDirectory: true)
    }

    @discardableResult
    static func ensureDirectories() throws -> URL {
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        return workDirectory
    }

    /// Yeni bir çalışma klasörü oluşturur (her işlem için ayrı).
    static func makeWorkDirectory() throws -> URL {
        try ensureDirectories()
        let folder = workDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
