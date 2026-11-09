// Original code-drawn tray icon. No external artwork, symbols or patient data.
import AppKit
let output = CommandLine.arguments.dropFirst().first ?? "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current?.shouldAntialias = true
let teal = NSColor(srgbRed: 0.06, green: 0.34, blue: 0.32, alpha: 1)
teal.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let tray = NSBezierPath(roundedRect: NSRect(x: 100, y: 244, width: 824, height: 536), xRadius: 70, yRadius: 70)
NSColor.white.setStroke(); tray.lineWidth = 24; tray.stroke()
let colors: [NSColor] = [NSColor(srgbRed: 0.64, green: 0.89, blue: 0.79, alpha: 1), NSColor(srgbRed: 1, green: 0.85, blue: 0.55, alpha: 1), NSColor(srgbRed: 0.72, green: 0.82, blue: 1, alpha: 1), NSColor(srgbRed: 0.88, green: 0.79, blue: 0.96, alpha: 1)]
for index in 0..<4 {
    let x = CGFloat(130 + index * 194)
    let cell = NSBezierPath(roundedRect: NSRect(x: x, y: 276, width: 182, height: 472), xRadius: 36, yRadius: 36)
    NSColor.white.withAlphaComponent(0.09).setFill(); cell.fill()
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: x + 91, yBy: 512)
    transform.rotate(byDegrees: -28)
    transform.concat()
    let pill = NSBezierPath(roundedRect: NSRect(x: -43, y: -100, width: 86, height: 200), xRadius: 43, yRadius: 43)
    colors[index].setFill(); pill.fill()
    let score = NSBezierPath(); score.move(to: NSPoint(x: -29, y: 0)); score.line(to: NSPoint(x: 29, y: 0))
    teal.withAlphaComponent(0.5).setStroke(); score.lineWidth = 7; score.stroke()
    NSGraphicsContext.restoreGraphicsState()
}
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Generated opaque 1024 × 1024 app icon")
