import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "LumaGuard/Assets.xcassets/AppIcon.appiconset")
let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for (name, size) in sizes {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: radius, yRadius: radius)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.09, green: 0.52, blue: 0.31, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.24, blue: 0.20, alpha: 1)
    ])?.draw(in: background, angle: -45)

    NSColor(calibratedRed: 0.94, green: 0.75, blue: 0.32, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.19, y: size * 0.47, width: size * 0.34, height: size * 0.34)).fill()

    NSColor(calibratedRed: 0.12, green: 0.34, blue: 0.27, alpha: 1).setFill()
    let moon = NSBezierPath(ovalIn: NSRect(x: size * 0.42, y: size * 0.23, width: size * 0.36, height: size * 0.36))
    moon.fill()
    NSColor(calibratedRed: 0.58, green: 0.89, blue: 0.63, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.35, y: size * 0.30, width: size * 0.36, height: size * 0.36)).fill()

    NSColor(calibratedWhite: 1, alpha: 0.22).setStroke()
    background.lineWidth = max(1, size * 0.012)
    background.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to render \(name)")
    }
    try png.write(to: output.appendingPathComponent(name))
}
