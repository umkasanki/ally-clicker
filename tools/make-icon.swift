import AppKit

// Renders the AllyClicker app icon (indigo squircle + dwell ring + cursor) to a
// 1024×1024 PNG. Mirrors the approved SVG concept. Run: swiftc make-icon.swift -o
// make-icon && ./make-icon out.png

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

// --- Map an SVG-style 200×200 y-down space onto an 832 body inset by 96. ---
let inset: CGFloat = 96
let body: CGFloat = CGFloat(size) - inset * 2   // 832
cg.translateBy(x: inset, y: CGFloat(size) - inset)   // top-left of body
cg.scaleBy(x: body / 200, y: -body / 200)            // y-down, 200-unit space

let space = CGColorSpace(name: CGColorSpace.sRGB)!

// --- Squircle tile with vertical indigo gradient ---
let tile = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 200, height: 200),
                  cornerWidth: 46, cornerHeight: 46, transform: nil)
cg.saveGState()
cg.addPath(tile); cg.clip()
let grad = CGGradient(colorsSpace: space,
                      colors: [rgb(0.655, 0.545, 0.980), rgb(0.427, 0.157, 0.850)] as CFArray,
                      locations: [0, 1])!
cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 200), options: [])

// Top sheen (white fading out over the upper half)
let sheen = CGGradient(colorsSpace: space,
                       colors: [rgb(1, 1, 1, 0.35), rgb(1, 1, 1, 0)] as CFArray,
                       locations: [0, 1])!
cg.drawLinearGradient(sheen, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 100), options: [])
cg.restoreGState()

// --- Dwell ring ---
cg.setLineWidth(12)
cg.setStrokeColor(rgb(1, 1, 1, 0.9))
cg.addEllipse(in: CGRect(x: 30, y: 30, width: 140, height: 140))
cg.strokePath()

// Faint progress arc from the top
cg.setStrokeColor(rgb(1, 1, 1, 0.45))
cg.setLineCap(.round)
cg.addArc(center: CGPoint(x: 100, y: 100), radius: 70,
          startAngle: -.pi / 2, endAngle: -.pi / 2 + 0.9, clockwise: false)
cg.strokePath()
cg.setLineCap(.butt)

// --- Cursor (enlarged 1.1×, nudged right inside the ring), with soft shadow ---
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: rgb(0, 0, 0, 0.28))
cg.translateBy(x: 108, y: 100)
cg.scaleBy(x: 1.1, y: 1.1)
cg.translateBy(x: -105, y: -107)
let cursor = CGMutablePath()
cursor.move(to: CGPoint(x: 78, y: 66))
cursor.addLine(to: CGPoint(x: 78, y: 138))
cursor.addLine(to: CGPoint(x: 96, y: 121))
cursor.addLine(to: CGPoint(x: 108, y: 148))
cursor.addLine(to: CGPoint(x: 120, y: 143))
cursor.addLine(to: CGPoint(x: 107, y: 117))
cursor.addLine(to: CGPoint(x: 132, y: 117))
cursor.closeSubpath()
cg.addPath(cursor)
cg.setFillColor(rgb(1, 1, 1))
cg.fillPath()
cg.restoreGState()

// --- Save PNG ---
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
