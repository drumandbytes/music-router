#!/usr/bin/swift
// Generates Resources/AppIcon.icns from an SF Symbol on a rounded gradient
// square — no design tools needed. Re-run after tweaking colors/symbol below.
import AppKit

let size = 1024
let symbolName = "music.quarternote.3"
let outputDir = "Resources"

func renderIcon() -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.22 // matches macOS's "squircle" proportions
    let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.29, green: 0.16, blue: 0.68, alpha: 1), // indigo
        NSColor(calibratedRed: 0.13, green: 0.53, blue: 0.82, alpha: 1), // blue
    ])
    gradient?.draw(in: backgroundPath, angle: -45)

    let sizeConfig = NSImage.SymbolConfiguration(pointSize: CGFloat(size) * 0.5, weight: .semibold)
    let colorConfig = NSImage.SymbolConfiguration(paletteColors: [.white])
    if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(sizeConfig.applying(colorConfig)) {
        let symbolSize = symbol.size
        let symbolRect = NSRect(
            x: (CGFloat(size) - symbolSize.width) / 2,
            y: (CGFloat(size) - symbolSize.height) / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )
        symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

func pngData(from image: NSImage, size: Int) -> Data? {
    guard let resized = NSImage(size: NSSize(width: size, height: size)) as NSImage? else { return nil }
    resized.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    resized.unlockFocus()

    guard
        let tiff = resized.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff)
    else { return nil }
    return bitmap.representation(using: .png, properties: [:])
}

let icon = renderIcon()
let iconsetPath = "\(outputDir)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, px) in sizes {
    guard let data = pngData(from: icon, size: px) else { continue }
    try data.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
}

print("Wrote \(iconsetPath) — run: iconutil -c icns \(iconsetPath) -o \(outputDir)/AppIcon.icns")
