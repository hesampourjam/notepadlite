// Renders the 1024×1024 app icon PNG. Usage: make_icon <out.png>
import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// Rounded-square body (macOS icon grid: 824pt body inside 1024 canvas).
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
let shadow = NSShadow()
shadow.shadowColor = rgb(0, 0, 0, 0.35)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
NSGraphicsContext.saveGraphicsState()
shadow.set()
rgb(60, 140, 70).setFill()
bodyPath.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: rgb(150, 215, 110), ending: rgb(40, 125, 60))!.draw(in: bodyPath, angle: -90)

// Paper sheet
let page = NSRect(x: 250, y: 200, width: 440, height: 600)
let pagePath = NSBezierPath(roundedRect: page, xRadius: 36, yRadius: 36)
NSGraphicsContext.saveGraphicsState()
let pageShadow = NSShadow()
pageShadow.shadowColor = rgb(0, 40, 0, 0.35)
pageShadow.shadowBlurRadius = 18
pageShadow.shadowOffset = NSSize(width: 0, height: -6)
pageShadow.set()
rgb(252, 252, 248).setFill()
pagePath.fill()
NSGraphicsContext.restoreGraphicsState()

// Text lines on the sheet
let lineColors = [rgb(60, 110, 200), rgb(170, 170, 170), rgb(200, 80, 70), rgb(170, 170, 170), rgb(70, 150, 80), rgb(170, 170, 170)]
let widths: [CGFloat] = [300, 340, 220, 320, 260, 180]
for i in 0..<6 {
    let y = page.maxY - 110 - CGFloat(i) * 72
    let indent: CGFloat = (i == 2 || i == 3) ? 50 : 0
    lineColors[i].setFill()
    NSBezierPath(roundedRect: NSRect(x: page.minX + 50 + indent, y: y, width: widths[i] - indent, height: 26),
                 xRadius: 13, yRadius: 13).fill()
}

// "++" badge
let badge = NSRect(x: 560, y: 150, width: 320, height: 320)
NSGraphicsContext.saveGraphicsState()
let badgeShadow = NSShadow()
badgeShadow.shadowColor = rgb(0, 0, 0, 0.3)
badgeShadow.shadowBlurRadius = 20
badgeShadow.shadowOffset = NSSize(width: 0, height: -8)
badgeShadow.set()
rgb(30, 90, 45).setFill()
NSBezierPath(ovalIn: badge).fill()
NSGraphicsContext.restoreGraphicsState()
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 170, weight: .heavy),
    .foregroundColor: NSColor.white,
]
let text = "++" as NSString
let ts = text.size(withAttributes: attrs)
text.draw(at: NSPoint(x: badge.midX - ts.width / 2, y: badge.midY - ts.height / 2 + 8), withAttributes: attrs)

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
