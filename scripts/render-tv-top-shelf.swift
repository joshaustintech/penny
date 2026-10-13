import AppKit
import Foundation

// Run from the repository root. Artwork contains branding only, never budget data.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Penny/Assets.xcassets/App Icon & Top Shelf Image.brandassets")
let background = NSColor(srgbRed: 0.04, green: 0.24, blue: 0.16, alpha: 1)
let cream = NSColor(srgbRed: 0.98, green: 0.95, blue: 0.84, alpha: 1)
let mint = NSColor(srgbRed: 0.56, green: 0.84, blue: 0.64, alpha: 1)
for (folder, width) in [("Top Shelf Image.imageset", 1920), ("Top Shelf Image Wide.imageset", 2320)] {
  for scale in [1, 2] {
    let size = NSSize(width: width * scale, height: 720 * scale)
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
      pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else { fatalError("Could not create top-shelf drawing surface") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    background.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: 720)).fill()
    let origin = CGFloat(width) / 2 - 450
    let center = NSPoint(x: origin + 170, y: 360)
    cream.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 145, y: center.y - 145, width: 290, height: 290)).fill()
    let quarter = NSBezierPath()
    quarter.move(to: center)
    quarter.appendArc(withCenter: center, radius: 145, startAngle: 0, endAngle: 90)
    quarter.close()
    background.setFill()
    quarter.fill()
    let insetCenter = NSPoint(x: center.x + 12, y: center.y + 12)
    let accent = NSBezierPath()
    accent.move(to: insetCenter)
    accent.appendArc(withCenter: insetCenter, radius: 133, startAngle: 0, endAngle: 90)
    accent.close()
    mint.setFill()
    accent.fill()
    let textOrigin = origin + 390
    ("Penny" as NSString).draw(at: NSPoint(x: textOrigin, y: 355), withAttributes: [
      .font: NSFont.systemFont(ofSize: 100, weight: .bold), .foregroundColor: cream])
    ("Every penny has a purpose." as NSString).draw(at: NSPoint(x: textOrigin, y: 280), withAttributes: [
      .font: NSFont.systemFont(ofSize: 32, weight: .medium), .foregroundColor: cream])
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
      fatalError("Could not encode top-shelf artwork")
    }
    try data.write(to: assets.appendingPathComponent(folder).appendingPathComponent("penny-\(scale)x.png"))
  }
  let contents: [String: Any] = ["images": [1, 2].map {
    ["idiom": "tv", "scale": "\($0)x", "filename": "penny-\($0)x.png"]
  }, "info": ["author": "xcode", "version": 1]]
  try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: assets.appendingPathComponent(folder).appendingPathComponent("Contents.json"))
}
