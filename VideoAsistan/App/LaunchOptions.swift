import Foundation

/// Uygulamaya komut satırından verilen seçenekler.
///
/// `--open <video>` ile uygulama açılır açılmaz verilen video işlenmeye başlar.
/// Bu, "Dosya ile aç" akışı ve tanıtım sitesi için ekran görüntüsü üretimi
/// açısından kullanışlıdır.
enum LaunchOptions {
    /// İşlenecek video (varsa).
    static var videoToOpen: URL?

    /// Argümanları okur.
    static func parse(arguments: [String]) {
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            if argument == "--open", let path = iterator.next() {
                videoToOpen = URL(fileURLWithPath: path)
                return
            }
        }
    }
}
