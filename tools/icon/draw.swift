// Draws Dispatch's app icon: a D whose bottom-left corner pinches into a speech-bubble tail,
// white on a WordPress-blue tile. Usage: swift draw.swift <out.png> [size]
// Apple's 1024 grid: an 824pt rounded square with a 100pt margin. make.sh turns it into AppIcon.icns.
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let px = Int(CommandLine.arguments.dropFirst(2).first ?? "1024") ?? 1024
let S: CGFloat = 1024

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

/// The mark, in the 1024 space (y up). Even-odd: the outer D-bubble minus the D's counter.
func mark() -> NSBezierPath {
    let p = NSBezierPath()
    let left: CGFloat = 316, top: CGFloat = 752, bottom: CGFloat = 300, cx: CGFloat = 498
    let r = (top - bottom) / 2, cy = bottom + r
    // Outer: flat-topped left side, a half circle on the right, and a tail off the bottom-left.
    p.move(to: NSPoint(x: left + 56, y: top))
    p.line(to: NSPoint(x: cx, y: top))
    p.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: r, startAngle: 90, endAngle: -90, clockwise: true)
    p.line(to: NSPoint(x: left + 150, y: bottom))
    p.curve(to: NSPoint(x: left - 34, y: bottom - 92), controlPoint1: NSPoint(x: left + 70, y: bottom),
            controlPoint2: NSPoint(x: left + 6, y: bottom - 40))
    p.curve(to: NSPoint(x: left, y: bottom + 120), controlPoint1: NSPoint(x: left - 6, y: bottom - 30),
            controlPoint2: NSPoint(x: left, y: bottom + 40))
    p.line(to: NSPoint(x: left, y: top - 56))
    p.curve(to: NSPoint(x: left + 56, y: top), controlPoint1: NSPoint(x: left, y: top - 25), controlPoint2: NSPoint(x: left + 25, y: top))
    p.close()
    // Counter: the D's hole.
    let w: CGFloat = 128, ir = r - w
    p.move(to: NSPoint(x: left + w, y: top - w))
    p.line(to: NSPoint(x: cx, y: top - w))
    p.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: ir, startAngle: 90, endAngle: -90, clockwise: true)
    p.line(to: NSPoint(x: left + w, y: bottom + w))
    p.close()
    p.windingRule = .evenOdd
    // Optically center the mark (its tail pulls it down-left).
    let b = p.bounds
    p.transform(using: AffineTransform(translationByX: 512 - b.midX + 8, byY: 512 - b.midY - 4))
    return p
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: S, height: S)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: tile, xRadius: 186, yRadius: 186)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = color(0x0b1450, 0.3); shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
color(0x3858e9).setFill(); shape.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
shape.addClip()
NSGradient(colors: [color(0x6d86ff), color(0x3858e9), color(0x2337b8)], atLocations: [0, 0.55, 1],
           colorSpace: .sRGB)!.draw(in: tile, angle: -90)
// A soft light from the top, as macOS icons have.
NSGradient(starting: color(0xffffff, 0.18), ending: color(0xffffff, 0))!.draw(in: NSRect(x: 100, y: 560, width: 824, height: 364), angle: -90)
let m = mark()
NSGraphicsContext.saveGraphicsState()
let ms = NSShadow()
ms.shadowColor = color(0x0b1450, 0.28); ms.shadowBlurRadius = 18; ms.shadowOffset = NSSize(width: 0, height: -8)
ms.set()
color(0xffffff).setFill(); m.fill()
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.restoreGraphicsState()

color(0x000000, 0.1).setStroke(); shape.lineWidth = 2; shape.stroke()
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
