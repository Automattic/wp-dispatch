import AppKit

/// Dispatch's mark: a D whose bottom-left corner pinches into a speech-bubble tail. The same shape
/// as the app icon (tools/icon/draw.swift); keep the two in step.
enum DispatchMark {
    /// The mark on Apple's 1024 icon grid (y up), counter cut out with the even-odd rule.
    static func path() -> NSBezierPath {
        let p = NSBezierPath()
        let left: CGFloat = 316, top: CGFloat = 752, bottom: CGFloat = 300, cx: CGFloat = 498
        let r = (top - bottom) / 2, cy = bottom + r
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
        let w: CGFloat = 128, ir = r - w
        p.move(to: NSPoint(x: left + w, y: top - w))
        p.line(to: NSPoint(x: cx, y: top - w))
        p.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: ir, startAngle: 90, endAngle: -90, clockwise: true)
        p.line(to: NSPoint(x: left + w, y: bottom + w))
        p.close()
        p.windingRule = .evenOdd
        return p
    }

    /// The mark scaled to fill `height` points, centered in a square of `size`.
    static func image(size: CGFloat, height: CGFloat, template: Bool = true) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let p = path()
            let b = p.bounds
            let scale = height / b.height
            var t = AffineTransform(translationByX: -b.minX, byY: -b.minY)
            t.append(AffineTransform(scaleByX: scale, byY: scale))
            t.append(AffineTransform(translationByX: (rect.width - b.width * scale) / 2, byY: (rect.height - height) / 2))
            p.transform(using: t)
            NSColor.black.setFill()
            p.fill()
            return true
        }
        image.isTemplate = template
        return image
    }

    /// For the menu bar: the same size as the system's own status icons.
    static let menuBar = image(size: 18, height: 15)
}
