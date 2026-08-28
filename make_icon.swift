import AppKit

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a).cgColor
}

// Apple-style squircle (continuous-corner) path via superellipse.
func squircle(in rect: CGRect, n: CGFloat = 5) -> CGPath {
    let p = CGMutablePath()
    let cx = rect.midX, cy = rect.midY, a = rect.width/2, b = rect.height/2
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * copysign(pow(abs(ct), 2/n), ct)
        let y = cy + b * copysign(pow(abs(st), 2/n), st)
        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
    }
    p.closeSubpath()
    return p
}

// ---- Background squircle with soft diagonal gradient ----
let margin: CGFloat = 76
let bg = CGRect(x: margin, y: margin, width: S - margin*2, height: S - margin*2)
let bgPath = squircle(in: bg, n: 4.8)

ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [rgb(96, 129, 255), rgb(124, 92, 234), rgb(99, 70, 220)] as CFArray,
                      locations: [0, 0.55, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: bg.minX, y: bg.maxY),
                       end: CGPoint(x: bg.maxX, y: bg.minY), options: [])
// subtle top-left sheen
let sheen = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [rgb(255, 255, 255, 0.28), rgb(255, 255, 255, 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawRadialGradient(sheen, startCenter: CGPoint(x: bg.minX + 180, y: bg.maxY - 140), startRadius: 0,
                       endCenter: CGPoint(x: bg.minX + 180, y: bg.maxY - 140), endRadius: 560, options: [])
ctx.restoreGState()

// ---- Soft photo card ----
let frame = CGRect(x: 296, y: 286, width: 432, height: 340)
let framePath = CGPath(roundedRect: frame, cornerWidth: 56, cornerHeight: 56, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 48, color: rgb(24, 20, 70, 0.40))
ctx.addPath(framePath); ctx.setFillColor(NSColor.white.cgColor); ctx.fillPath()
ctx.restoreGState()

// inner landscape
let inner = frame.insetBy(dx: 26, dy: 26)
let innerPath = CGPath(roundedRect: inner, cornerWidth: 34, cornerHeight: 34, transform: nil)
ctx.saveGState()
ctx.addPath(innerPath); ctx.clip()
let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                     colors: [rgb(191, 232, 255), rgb(224, 245, 255)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(sky, start: CGPoint(x: inner.minX, y: inner.maxY),
                       end: CGPoint(x: inner.minX, y: inner.minY), options: [])
// sun
ctx.setFillColor(rgb(255, 203, 71))
ctx.fillEllipse(in: CGRect(x: inner.minX + 44, y: inner.maxY - 128, width: 96, height: 96))
// back hill (rounded)
ctx.setFillColor(rgb(120, 209, 130))
ctx.beginPath()
ctx.move(to: CGPoint(x: inner.minX, y: inner.minY))
ctx.addQuadCurve(to: CGPoint(x: inner.midX, y: inner.minY + 40),
                 control: CGPoint(x: inner.minX + 120, y: inner.minY + 190))
ctx.addQuadCurve(to: CGPoint(x: inner.maxX, y: inner.minY + 10),
                 control: CGPoint(x: inner.maxX - 120, y: inner.minY + 150))
ctx.addLine(to: CGPoint(x: inner.maxX, y: inner.minY))
ctx.closePath(); ctx.fillPath()
// front hill
ctx.setFillColor(rgb(52, 178, 92))
ctx.beginPath()
ctx.move(to: CGPoint(x: inner.minX, y: inner.minY))
ctx.addQuadCurve(to: CGPoint(x: inner.minX + 210, y: inner.minY + 30),
                 control: CGPoint(x: inner.minX + 110, y: inner.minY + 150))
ctx.addQuadCurve(to: CGPoint(x: inner.maxX, y: inner.minY),
                 control: CGPoint(x: inner.maxX - 140, y: inner.minY + 120))
ctx.closePath(); ctx.fillPath()
ctx.restoreGState()

// ---- Rounded house roof over the card ----
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 22, color: rgb(24, 20, 70, 0.30))
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setFillColor(NSColor.white.cgColor)
ctx.setLineWidth(46)
ctx.setLineJoin(.round)
ctx.setLineCap(.round)
let apex = CGPoint(x: 512, y: 792)
ctx.beginPath()
ctx.move(to: CGPoint(x: 300, y: 632))
ctx.addLine(to: apex)
ctx.addLine(to: CGPoint(x: 724, y: 632))
ctx.strokePath()
ctx.restoreGState()

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("encode failed") }
try! png.write(to: URL(fileURLWithPath: "icon_1024.png"))
print("wrote icon_1024.png")
