import AppKit

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: 1).cgColor
}

// ---- Rounded-rect app background with gradient ----
let margin: CGFloat = 90
let bg = CGRect(x: margin, y: margin, width: S - margin*2, height: S - margin*2)
let corner: CGFloat = 200
let bgPath = CGPath(roundedRect: bg, cornerWidth: corner, cornerHeight: corner, transform: nil)

ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [color(59, 130, 246), color(79, 70, 229)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
ctx.restoreGState()

// ---- White photo frame ----
let frame = CGRect(x: 300, y: 300, width: 424, height: 340)
let framePath = CGPath(roundedRect: frame, cornerWidth: 36, cornerHeight: 36, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: color(20, 24, 60).copy(alpha: 0.35))
ctx.addPath(framePath)
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillPath()
ctx.restoreGState()

// clip inside frame for the "landscape"
ctx.saveGState()
let innerPath = CGPath(roundedRect: frame.insetBy(dx: 22, dy: 22), cornerWidth: 18, cornerHeight: 18, transform: nil)
ctx.addPath(innerPath); ctx.clip()
let inner = frame.insetBy(dx: 22, dy: 22)
// sky
ctx.setFillColor(color(186, 230, 253))
ctx.fill(inner)
// sun
ctx.setFillColor(color(250, 204, 21))
ctx.fillEllipse(in: CGRect(x: inner.minX + 40, y: inner.maxY - 120, width: 90, height: 90))
// mountains
ctx.setFillColor(color(34, 197, 94))
ctx.beginPath()
ctx.move(to: CGPoint(x: inner.minX, y: inner.minY))
ctx.addLine(to: CGPoint(x: inner.minX + 150, y: inner.minY + 160))
ctx.addLine(to: CGPoint(x: inner.minX + 250, y: inner.minY + 60))
ctx.addLine(to: CGPoint(x: inner.maxX, y: inner.minY + 200))
ctx.addLine(to: CGPoint(x: inner.maxX, y: inner.minY))
ctx.closePath(); ctx.fillPath()
ctx.setFillColor(color(22, 163, 74))
ctx.beginPath()
ctx.move(to: CGPoint(x: inner.minX + 180, y: inner.minY))
ctx.addLine(to: CGPoint(x: inner.minX + 330, y: inner.minY + 150))
ctx.addLine(to: CGPoint(x: inner.maxX, y: inner.minY))
ctx.closePath(); ctx.fillPath()
ctx.restoreGState()

// ---- House roof over the frame ----
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: color(20, 24, 60).copy(alpha: 0.30))
ctx.setFillColor(NSColor.white.cgColor)
ctx.beginPath()
let roofY: CGFloat = frame.maxY - 4
ctx.move(to: CGPoint(x: 512, y: 780))          // apex
ctx.addLine(to: CGPoint(x: 268, y: roofY))     // left eave
ctx.addLine(to: CGPoint(x: 340, y: roofY))
ctx.addLine(to: CGPoint(x: 512, y: 700))
ctx.addLine(to: CGPoint(x: 684, y: roofY))
ctx.addLine(to: CGPoint(x: 756, y: roofY))
ctx.closePath(); ctx.fillPath()
ctx.restoreGState()

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("encode failed")
}
try! png.write(to: URL(fileURLWithPath: "icon_1024.png"))
print("wrote icon_1024.png")
