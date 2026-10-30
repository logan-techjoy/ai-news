// Draws the AI News Desk app icon: the desk's navy with the system newspaper symbol in amber.
// Writes a 1024 px PNG; macos/make-app turns it into AppIcon.icns with iconutil.
// Usage: swift macos/make-icon.swift <out.png>
import AppKit

let size = 1024.0
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: 824 px rounded square centred in 1024, corner radius ~185
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(srgbRed: 0.10, green: 0.19, blue: 0.48, alpha: 1),   // lighter top
           ending: NSColor(srgbRed: 0.043, green: 0.102, blue: 0.29, alpha: 1))!  // #0B1A4A, the desk
  .draw(in: shape, angle: -90)

let amber = NSColor(srgbRed: 0.96, green: 0.65, blue: 0.14, alpha: 1)
let config = NSImage.SymbolConfiguration(pointSize: 440, weight: .semibold)
  .applying(NSImage.SymbolConfiguration(paletteColors: [amber]))
let glyph = NSImage(systemSymbolName: "newspaper.fill", accessibilityDescription: nil)!
  .withSymbolConfiguration(config)!
let g = glyph.size
glyph.draw(in: NSRect(x: (size - g.width) / 2, y: (size - g.height) / 2, width: g.width, height: g.height))

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
