// Ekran görüntüsündeki renk dengesizliğini (yeşil duvar kâğıdı yansıması) nötrler.
//
//   swift Tools/normalize_screenshot.swift <giriş.png> <çıktı.png>
//
// Yöntem: kanal başına ortalama parlaklığı eşitleyen beyaz dengesi (auto white balance).
// Uygulamanın kendi renkleri korunur, yalnızca ortam yansıması giderilir.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("Kullanım: swift normalize_screenshot.swift <giriş.png> <çıktı.png>")
    exit(1)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])

guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    print("HATA: görüntü okunamadı")
    exit(1)
}

let width = image.width
let height = image.height
let bytesPerPixel = 4

guard let context = CGContext(data: nil,
                              width: width,
                              height: height,
                              bitsPerComponent: 8,
                              bytesPerRow: width * bytesPerPixel,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    print("HATA: bağlam oluşturulamadı")
    exit(1)
}

context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

guard let rawData = context.data else {
    print("HATA: piksel verisi alınamadı")
    exit(1)
}

let pixels = rawData.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
let pixelCountTotal = width * height * bytesPerPixel

// Kanal ortalamaları.
var sumR: Double = 0, sumG: Double = 0, sumB: Double = 0
let pixelCount = Double(width * height)
for index in stride(from: 0, to: pixelCountTotal, by: bytesPerPixel) {
    sumR += Double(pixels[index])
    sumG += Double(pixels[index + 1])
    sumB += Double(pixels[index + 2])
}
let meanR = sumR / pixelCount
let meanG = sumG / pixelCount
let meanB = sumB / pixelCount
let mean = (meanR + meanG + meanB) / 3

print(String(format: "ortalama R %.1f  G %.1f  B %.1f", meanR, meanG, meanB))

// Kazançlar: yeşil baskınlığını nötrle, aşırı düzeltmeyi engelle.
func gain(_ channelMean: Double) -> Double {
    let raw = mean / max(channelMean, 1)
    return min(max(raw, 0.90), 1.10)
}

let gainR = gain(meanR)
let gainG = gain(meanG)
let gainB = gain(meanB)
print(String(format: "kazanç R %.3f  G %.3f  B %.3f", gainR, gainG, gainB))

for index in stride(from: 0, to: pixelCountTotal, by: bytesPerPixel) {
    pixels[index] = UInt8(min(255.0, Double(pixels[index]) * gainR))
    pixels[index + 1] = UInt8(min(255.0, Double(pixels[index + 1]) * gainG))
    pixels[index + 2] = UInt8(min(255.0, Double(pixels[index + 2]) * gainB))
}

guard let corrected = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(outputURL as CFURL,
                                                         UTType.png.identifier as CFString,
                                                         1,
                                                         nil) else {
    print("HATA: çıktı oluşturulamadı")
    exit(1)
}
CGImageDestinationAddImage(destination, corrected, nil)
CGImageDestinationFinalize(destination)
print("yazıldı: \(outputURL.path)")
