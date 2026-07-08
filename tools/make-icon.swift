import AppKit

// Renders the AllyClicker app icon (v2: indigo squircle + plump rounded cursor with
// a subtle white→lavender gradient, no ring) to a 1024×1024 PNG. Mirrors the
// approved SVG (tools/AppIcon.svg). Run:
//   swiftc make-icon.swift -o make-icon && ./make-icon out.png

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
let space = CGColorSpace(name: CGColorSpace.sRGB)!

// Map an SVG-style 200×200 y-down space onto an 832 body inset 96px in the canvas.
let inset: CGFloat = 96
let body: CGFloat = CGFloat(size) - inset * 2
cg.translateBy(x: inset, y: CGFloat(size) - inset)
cg.scaleBy(x: body / 200, y: -body / 200)

// --- Squircle tile: vertical indigo gradient + top sheen ---
let tile = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 200, height: 200),
                  cornerWidth: 46, cornerHeight: 46, transform: nil)
cg.saveGState()
cg.addPath(tile); cg.clip()
let grad = CGGradient(colorsSpace: space,
                      colors: [rgb(0.655, 0.545, 0.980), rgb(0.427, 0.157, 0.850)] as CFArray,
                      locations: [0, 1])!
cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 200), options: [])
let sheen = CGGradient(colorsSpace: space,
                       colors: [rgb(1, 1, 1, 0.35), rgb(1, 1, 1, 0)] as CFArray,
                       locations: [0, 1])!
cg.drawLinearGradient(sheen, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 100), options: [])
cg.restoreGState()

// --- Plump rounded cursor (gradient fill, soft shadow, no ring) ---
cg.saveGState()
cg.translateBy(x: 104, y: 100)   // centered, nudged slightly right
cg.scaleBy(x: 1.5, y: 1.5)
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
// Rounded, fattened outline (round joins/caps make it plump like the Mail envelope).
let fat = cursor.copy(strokingWithWidth: 11, lineCap: .round, lineJoin: .round, miterLimit: 10)

// Base fill establishes the shape and casts a soft shadow.
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: 5), blur: 7, color: rgb(0.16, 0.04, 0.37, 0.35))
cg.addPath(cursor); cg.addPath(fat)
cg.setFillColor(rgb(1, 1, 1))
cg.fillPath(using: .winding)
cg.restoreGState()

// Gradient fill (white top → lavender bottom) clipped to the cursor.
cg.saveGState()
cg.addPath(cursor); cg.addPath(fat)
cg.clip(using: .winding)
let curGrad = CGGradient(colorsSpace: space,
                         colors: [rgb(1, 1, 1), rgb(0.886, 0.851, 0.961)] as CFArray,
                         locations: [0, 1])!
cg.drawLinearGradient(curGrad, start: CGPoint(x: 105, y: 60), end: CGPoint(x: 105, y: 150),
                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
cg.restoreGState()

cg.restoreGState()

// --- Save PNG ---
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
