import AppKit

// ScreenBridge: two displays joined by opposing arrows. All sizes rendered from vectors.
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = graphics
    let ctx = graphics.cgContext
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 90, y: 90, width: 844, height: 844), xRadius: 190, yRadius: 190)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: NSColor.black.withAlphaComponent(0.24).cgColor)
    NSColor(calibratedRed: 0.025, green: 0.22, blue: 0.25, alpha: 1).setFill()
    tile.fill()
    ctx.restoreGState()
    NSGradient(colors: [NSColor(calibratedRed: 0.04, green: 0.60, blue: 0.57, alpha: 1),
                        NSColor(calibratedRed: 0.02, green: 0.20, blue: 0.28, alpha: 1)])!.draw(in: tile, angle: -75)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    tile.lineWidth = 2
    tile.stroke()
    func screen(_ rect: NSRect, _ color: NSColor) {
        let outline = NSBezierPath(roundedRect: rect, xRadius: 30, yRadius: 30)
        color.withAlphaComponent(0.13).setFill(); outline.fill()
        color.setStroke(); outline.lineWidth = 22; outline.stroke()
        let foot = NSBezierPath()
        foot.move(to: NSPoint(x: rect.midX, y: rect.minY - 6))
        foot.line(to: NSPoint(x: rect.midX, y: rect.minY - 50))
        foot.move(to: NSPoint(x: rect.midX - 55, y: rect.minY - 50))
        foot.line(to: NSPoint(x: rect.midX + 55, y: rect.minY - 50))
        foot.lineWidth = 22; foot.lineCapStyle = .round; foot.stroke()
    }
    screen(NSRect(x: 217, y: 514, width: 352, height: 225), .white)
    screen(NSRect(x: 455, y: 292, width: 352, height: 225), NSColor(calibratedRed: 0.58, green: 1, blue: 0.84, alpha: 1))
    func arrow(_ points: [NSPoint], head: [NSPoint], color: NSColor) {
        color.setStroke()
        let path = NSBezierPath(); path.move(to: points[0])
        for point in points.dropFirst() { path.line(to: point) }
        path.move(to: head[0]); path.line(to: head[1]); path.line(to: head[2])
        path.lineWidth = 27; path.lineCapStyle = .round; path.lineJoinStyle = .round; path.stroke()
    }
    arrow([NSPoint(x: 620, y: 680), NSPoint(x: 747, y: 680), NSPoint(x: 747, y: 592)],
          head: [NSPoint(x: 711, y: 624), NSPoint(x: 747, y: 588), NSPoint(x: 783, y: 624)], color: .white)
    arrow([NSPoint(x: 402, y: 347), NSPoint(x: 277, y: 347), NSPoint(x: 277, y: 432)],
          head: [NSPoint(x: 241, y: 401), NSPoint(x: 277, y: 437), NSPoint(x: 313, y: 401)],
          color: NSColor(calibratedRed: 0.58, green: 1, blue: 0.84, alpha: 1))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("icon_\(size).png"))
}
print("ScreenBridge icons rendered: 16–1024 px")
