// VideoAsistan uygulama ikonunu üretir.
//
// Çıktı: <çıktı-dizini>/icon-1024.png (1024x1024 PNG)
// Kullanım:  swift Tools/make_icon.swift <çıktı-dizini>
//
// Tasarım: Video karesi + oynat üçgeni + altyazı satırları, indigo→mor gradyan
// macOS "squircle" üzerinde. Geometri Apple'ın ikon kılavuzuna göre tam 1024x1024
// tuvali kaplar; filigran veya harici görsel yoktur.
//
// Tüm ölçüler "yukarıdan aşağı" (top-down) tanımlanır; çizim sırasında
// CoreGraphics'in taban-yukarı koordinat sistemine çevrilir.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let canvasSize = 1024.0

// MARK: - Yardımcılar

/// macOS ikonlarının kullandığı süperelips (squircle) yolu.
func squirclePath(in rect: CGRect, exponent: Double = 5.0) -> CGPath {
    let path = CGMutablePath()
    let steps = 1024
    let power = 2.0 / exponent

    for index in 0...steps {
        let angle = Double(index) / Double(steps) * 2 * .pi
        let cosValue = cos(angle)
        let sinValue = sin(angle)
        let x = copysign(pow(abs(cosValue), power), cosValue)
        let y = copysign(pow(abs(sinValue), power), sinValue)
        let point = CGPoint(x: rect.midX + x * rect.width / 2,
                           y: rect.midY + y * rect.height / 2)
        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    return path
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

func makeContext(width: Int, height: Int) -> CGContext {
    CGContext(data: nil,
              width: width,
              height: height,
              bitsPerComponent: 8,
              bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

/// Yukarıdan aşağı tanımlanmış dikdörtgeni taban-yukarı koordinata çevirir.
func bottomUp(_ rect: CGRect) -> CGRect {
    CGRect(x: rect.minX, y: canvasSize - rect.maxY, width: rect.width, height: rect.height)
}

/// Yukarıdan aşağı tanımlanmış noktayı taban-yukarı koordinata çevirir.
func bottomUp(_ point: CGPoint) -> CGPoint {
    CGPoint(x: point.x, y: canvasSize - point.y)
}

// MARK: - Glif geometrisi (yukarıdan aşağı, 1024 birimlik tuval)

let frameRect = CGRect(x: 236, y: 204, width: 552, height: 408)
let frameCorner: CGFloat = 54
let frameStroke: CGFloat = 44

let trianglePoints = [
    CGPoint(x: 450, y: 324),
    CGPoint(x: 450, y: 492),
    CGPoint(x: 592, y: 408)
]

let captionBarOne = CGRect(x: 236, y: 686, width: 552, height: 44)
let captionBarTwo = CGRect(x: 236, y: 776, width: 380, height: 44)
let captionCorner: CGFloat = 22

/// Glifi (beyaz sembol) şeffaf bir katmana çizer.
func drawGlyph(in context: CGContext) {
    context.setFillColor(color(0xFFFFFF))
    context.setStrokeColor(color(0xFFFFFF))

    // Video karesi: yuvarlatılmış dikdörtgen çerçeve.
    context.addPath(CGPath(roundedRect: bottomUp(frameRect),
                           cornerWidth: frameCorner,
                           cornerHeight: frameCorner,
                           transform: nil))
    context.setLineWidth(frameStroke)
    context.setLineJoin(.round)
    context.strokePath()

    // Oynat üçgeni: kalın yuvarlak birleşimli çizgi ile köşeleri yuvarlatılmış
    // dolu üçgen. (Çizgili yol tek başına halka bırakır, bu yüzden üçgen ayrıca
    // doldurulur.)
    let triangle = CGMutablePath()
    triangle.move(to: bottomUp(trianglePoints[0]))
    triangle.addLine(to: bottomUp(trianglePoints[1]))
    triangle.addLine(to: bottomUp(trianglePoints[2]))
    triangle.closeSubpath()

    let rounded = triangle.copy(strokingWithWidth: 34,
                                 lineCap: .round,
                                 lineJoin: .round,
                                 miterLimit: 12,
                                 transform: CGAffineTransform.identity)
    context.addPath(rounded)
    context.fillPath()
    context.addPath(triangle)
    context.fillPath()

    // Altyazı satırları.
    for bar in [captionBarOne, captionBarTwo] {
        context.addPath(CGPath(roundedRect: bottomUp(bar),
                               cornerWidth: captionCorner,
                               cornerHeight: captionCorner,
                               transform: nil))
        context.fillPath()
    }
}

// MARK: - Ana üretim

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1
                           ? CommandLine.arguments[1]
                           : FileManager.default.currentDirectoryPath)
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let mainContext = makeContext(width: Int(canvasSize), height: Int(canvasSize))
let canvas = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
let squircle = squirclePath(in: canvas)

// 1) Gradyan zemin.
mainContext.saveGState()
mainContext.addPath(squircle)
mainContext.clip()

let gradientColors = [color(0x4F3FE8), color(0x7C4DFF), color(0xA855F7)] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: gradientColors,
                          locations: [0, 0.55, 1])!
mainContext.drawLinearGradient(gradient,
                               start: CGPoint(x: 90, y: canvasSize - 40),
                               end: CGPoint(x: 950, y: 90),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// 2) Üstten hafif ışık (macOS ikonlarındaki derinlik hissi).
let highlightColors = [color(0xFFFFFF, alpha: 0.20), color(0xFFFFFF, alpha: 0.0)] as CFArray
let highlight = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                           colors: highlightColors,
                           locations: [0, 0.62])!
mainContext.drawLinearGradient(highlight,
                               start: CGPoint(x: 0, y: canvasSize),
                               end: CGPoint(x: 0, y: canvasSize * 0.38),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
mainContext.restoreGState()

// 3) Glif: tek bir katmana çizilip gölgeli olarak yerleştirilir.
let glyphContext = makeContext(width: Int(canvasSize), height: Int(canvasSize))
drawGlyph(in: glyphContext)

if let glyphImage = glyphContext.makeImage() {
    mainContext.saveGState()
    mainContext.setShadow(offset: CGSize(width: 0, height: 12),
                          blur: 26,
                          color: color(0x1B0B4D, alpha: 0.28))
    mainContext.draw(glyphImage, in: canvas)
    mainContext.restoreGState()
}

// 4) PNG olarak kaydet.
guard let finalImage = mainContext.makeImage() else {
    fatalError("Görüntü oluşturulamadı")
}

let outputURL = outputDirectory.appendingPathComponent("icon-1024.png")
guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL,
                                                         UTType.png.identifier as CFString,
                                                         1,
                                                         nil) else {
    fatalError("PNG dosyası oluşturulamadı: \(outputURL.path)")
}
CGImageDestinationAddImage(destination, finalImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("PNG yazılamadı: \(outputURL.path)")
}

print("İkon üretildi: \(outputURL.path)")
