import AppKit

let W: CGFloat = 1200, H: CGFloat = 630
let out = NSImage(size: NSSize(width: W, height: H))
out.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
func rgb(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat,_ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a).cgColor
}

// Brand diagonal gradient
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [rgb(96,129,255), rgb(124,92,234), rgb(99,70,220)] as CFArray,
                      locations: [0,0.55,1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])
// top-left sheen
let sheen = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [rgb(255,255,255,0.20), rgb(255,255,255,0)] as CFArray, locations: [0,1])!
ctx.drawRadialGradient(sheen, startCenter: CGPoint(x: 120, y: H-60), startRadius: 0,
                       endCenter: CGPoint(x: 120, y: H-60), endRadius: 620, options: [])

// ---- Right: framed screenshot ----
if let shot = NSImage(contentsOfFile: "docs/screenshot.jpg") {
    let cardW: CGFloat = 600, aspect = shot.size.height / max(shot.size.width, 1)
    let cardH = cardW * aspect
    let cardRect = NSRect(x: W - cardW - 48, y: (H - cardH)/2, width: cardW, height: cardH)
    // shadow via filled rounded shape
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowBlurRadius = 44
    sh.shadowOffset = NSSize(width: 0, height: -16)
    sh.shadowColor = NSColor.black.withAlphaComponent(0.40); sh.set()
    let base = NSBezierPath(roundedRect: cardRect, xRadius: 16, yRadius: 16)
    NSColor.white.setFill(); base.fill()
    NSGraphicsContext.restoreGraphicsState()
    // title bar
    let barH: CGFloat = 30
    let barRect = NSRect(x: cardRect.minX, y: cardRect.maxY - barH, width: cardRect.width, height: barH)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: cardRect, xRadius: 16, yRadius: 16).addClip()
    NSColor(cgColor: rgb(36,31,46))!.setFill(); NSBezierPath(rect: barRect).fill()
    for (i, c) in [rgb(255,95,87), rgb(254,188,46), rgb(40,200,64)].enumerated() {
        NSColor(cgColor: c)!.setFill()
        NSBezierPath(ovalIn: NSRect(x: cardRect.minX + 14 + CGFloat(i)*18, y: barRect.midY - 5, width: 10, height: 10)).fill()
    }
    // screenshot below the bar
    let imgRect = NSRect(x: cardRect.minX, y: cardRect.minY, width: cardRect.width, height: cardRect.height - barH)
    shot.draw(in: imgRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

// ---- Left: icon + text ----
let leftX: CGFloat = 64
if let icon = NSImage(contentsOfFile: "icon_1024.png") {
    let r = NSRect(x: leftX, y: H - 72 - 104, width: 104, height: 104)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: r, xRadius: 24, yRadius: 24).addClip()
    icon.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func draw(_ s: String, x: CGFloat, yTop: CGFloat, w: CGFloat, size: CGFloat,
          weight: NSFont.Weight, color: NSColor, lines: Int = 1) {
    let p = NSMutableParagraphStyle(); p.lineSpacing = 2
    let a: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p]
    NSAttributedString(string: s, attributes: a).draw(in: NSRect(x: x, y: H - yTop - size*CGFloat(lines)*1.25, width: w, height: size*CGFloat(lines)*1.4))
}

draw("galleRE", x: leftX, yTop: 210, w: 480, size: 76, weight: .heavy, color: .white)
draw("The best way to organize, optimize, and manage your real estate MLS photos.",
     x: leftX, yTop: 300, w: 470, size: 27, weight: .medium, color: NSColor.white.withAlphaComponent(0.92), lines: 3)

// chip
let chip = "Free · macOS · Open source" as NSString
let chipFont = NSFont.systemFont(ofSize: 20, weight: .semibold)
let chipSize = chip.size(withAttributes: [.font: chipFont])
let chipRect = NSRect(x: leftX, y: 70, width: chipSize.width + 36, height: 44)
NSColor.white.withAlphaComponent(0.16).setFill()
NSBezierPath(roundedRect: chipRect, xRadius: 22, yRadius: 22).fill()
chip.draw(at: NSPoint(x: chipRect.minX + 18, y: chipRect.midY - chipSize.height/2),
          withAttributes: [.font: chipFont, .foregroundColor: NSColor.white])

out.unlockFocus()
guard let tiff = out.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError() }
try! png.write(to: URL(fileURLWithPath: "docs/social.png"))
print("wrote docs/social.png (\(Int(W))x\(Int(H)))")
