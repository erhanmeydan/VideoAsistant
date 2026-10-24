// Çalışan uygulamanın pencere konumunu ve başlığını yazdır.
//
// Çıktı: "x,y,width,height" biçiminde tek satır (screencapture -R ile kullanılır).

import Foundation
import CoreGraphics

guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}

for window in list {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    guard owner.contains("VideoAsistant") else { continue }
    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    guard layer == 0 else { continue }

    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let x = Int(bounds["X"] as? Double ?? 0)
    let y = Int(bounds["Y"] as? Double ?? 0)
    let width = Int(bounds["Width"] as? Double ?? 0)
    let height = Int(bounds["Height"] as? Double ?? 0)
    let name = window[kCGWindowName as String] as? String ?? ""

    print("\(x),\(y),\(width),\(height)")
    if !name.isEmpty {
        print("Başlık: \(name)")
    }
}
