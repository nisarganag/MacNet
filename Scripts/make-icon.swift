// Renders MacNet's app icon at every size macOS asks for and packs the set
// into Resources/AppIcon.icns. Run from the repository root:
//
//     swift Scripts/make-icon.swift
//
// Drawn as vectors at each size rather than downscaled from one bitmap, so
// the 16 and 32 px variants stay crisp. Monochrome by the owner's request —
// dark graphite glass, silver arrows (upload above download) over a faint
// mirrored waveform, the panel's own motif.
import AppKit

let canvas: CGFloat = 1024
let body = NSRect(x: 100, y: 100, width: 824, height: 824)   // macOS icon grid
let corner: CGFloat = 186

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func arrow(centerX: CGFloat, centerY: CGFloat, up: Bool) -> NSBezierPath {
    let height: CGFloat = 400, shaft: CGFloat = 104, headWidth: CGFloat = 276, headHeight: CGFloat = 176
    let s: CGFloat = up ? 1 : -1
    let tip = centerY + s * height / 2
    let headBase = tip - s * headHeight
    let tail = centerY - s * height / 2
    return roundedPolygon([
        NSPoint(x: centerX, y: tip),
        NSPoint(x: centerX + headWidth / 2, y: headBase),
        NSPoint(x: centerX + shaft / 2, y: headBase),
        NSPoint(x: centerX + shaft / 2, y: tail),
        NSPoint(x: centerX - shaft / 2, y: tail),
        NSPoint(x: centerX - shaft / 2, y: headBase),
        NSPoint(x: centerX - headWidth / 2, y: headBase),
    ], radius: 18)
}

/// A closed polygon with every corner rounded by the same radius.
func roundedPolygon(_ points: [NSPoint], radius: CGFloat) -> NSBezierPath {
    let path = CGMutablePath()
    let last = points[points.count - 1], first = points[0]
    path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
    for i in points.indices {
        let corner = points[i], next = points[(i + 1) % points.count]
        path.addArc(tangent1End: corner, tangent2End: next, radius: radius)
    }
    path.closeSubpath()
    return NSBezierPath(cgPath: path)
}

/// A fixed, hand-tuned sequence so the waveform reads as real traffic.
let wave: [CGFloat] = [0.16, 0.24, 0.20, 0.34, 0.30, 0.46, 0.40, 0.52, 0.42, 0.34, 0.38, 0.50, 0.44, 0.30, 0.24, 0.32,
                       0.40, 0.36, 0.26, 0.20, 0.28, 0.22]

func waveform(mid: CGFloat, reach: CGFloat, direction: CGFloat, phase: Int) -> NSBezierPath {
    let left = body.minX + 40, right = body.maxX - 40
    let step = (right - left) / CGFloat(wave.count - 1)
    let points = wave.indices.map { i in
        NSPoint(x: left + CGFloat(i) * step, y: mid + direction * wave[(i + phase) % wave.count] * reach)
    }
    let path = NSBezierPath()
    path.move(to: NSPoint(x: left, y: mid))
    path.line(to: points[0])
    for i in 1 ..< points.count {
        let a = points[i - 1], b = points[i]
        let midpoint = NSPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        path.curve(to: midpoint, controlPoint1: a, controlPoint2: a)
    }
    path.line(to: points[points.count - 1])
    path.line(to: NSPoint(x: right, y: mid))
    path.close()
    return path
}

func drawIcon() {
    let squircle = NSBezierPath(roundedRect: body, xRadius: corner, yRadius: corner)

    // Depth: the soft drop shadow every macOS icon sits on.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, 0.38)
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    color(0x0A0A0B).setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    NSGradient(colors: [color(0x040404), color(0x151517), color(0x2B2B2E)],
               atLocations: [0, 0.6, 1], colorSpace: .sRGB)!.draw(in: body, angle: 90)
    // A soft light source above the top edge, like glass catching a lamp.
    NSGradient(colors: [color(0xFFFFFF, 0.13), color(0xFFFFFF, 0.0)])!
        .draw(fromCenter: NSPoint(x: body.midX, y: body.maxY + 40), radius: 0,
              toCenter: NSPoint(x: body.midX, y: body.maxY + 40), radius: 560, options: [])

    // Faint traffic waveform behind the arrows.
    let mid = body.midY
    color(0xFFFFFF, 0.08).setFill()
    waveform(mid: mid, reach: 280, direction: 1, phase: 0).fill()
    color(0xFFFFFF, 0.05).setFill()
    waveform(mid: mid, reach: 280, direction: -1, phase: 7).fill()
    color(0xFFFFFF, 0.18).setFill()
    NSRect(x: body.minX, y: mid - 2, width: body.width, height: 4).fill()

    // The arrows: upload higher on the left, download lower on the right.
    for (path, colors) in [
        (arrow(centerX: 400, centerY: 556, up: true), [color(0xC4C4C9), color(0xFFFFFF)]),
        (arrow(centerX: 624, centerY: 468, up: false), [color(0x55555A), color(0x9C9CA1)]),
    ] {
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = color(0x000000, 0.55)
        glow.shadowBlurRadius = 26
        glow.shadowOffset = NSSize(width: 0, height: -10)
        glow.set()
        colors[0].setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: colors)!.draw(in: path, angle: 90)
        // A hairline of light along the edges keeps the arrow reading as glass.
        path.lineWidth = 3
        color(0xFFFFFF, 0.30).setStroke()
        path.stroke()
    }

    // Glass: a sheen across the upper half and a bright rim.
    NSGradient(colors: [color(0xFFFFFF, 0.0), color(0xFFFFFF, 0.12)])!
        .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    let rim = NSBezierPath(roundedRect: body.insetBy(dx: 2, dy: 2), xRadius: corner - 2, yRadius: corner - 2)
    rim.lineWidth = 4
    color(0xFFFFFF, 0.20).setStroke()
    rim.stroke()
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = fm.temporaryDirectory.appendingPathComponent("MacNet-\(UUID().uuidString).iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try render(pixels: 1024).write(to: URL(fileURLWithPath: "Resources/AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
try? fm.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("wrote Resources/AppIcon.icns and Resources/AppIcon-1024.png")
