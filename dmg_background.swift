import AppKit

let W: CGFloat = 660, H: CGFloat = 400
let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
func rgb(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat,_ a: CGFloat = 1) -> CGColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a).cgColor
}

// Soft light background with a faint brand tint at the top.
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [rgb(244,245,252), rgb(236,237,247)] as CFArray, locations: [0,1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

// Title + subtitle (top). CoreGraphics origin is bottom-left.
func drawText(_ s: String, _ size: CGFloat, _ color: NSColor, _ weight: NSFont.Weight, yTop: CGFloat) {
    let p = NSMutableParagraphStyle(); p.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color, .paragraphStyle: p]
    let str = NSAttributedString(string: s, attributes: attrs)
    let r = NSRect(x: 0, y: H - yTop - size*1.2, width: W, height: size*1.4)
    str.draw(in: r)
}
drawText("Install galleRE", 26, NSColor(srgbRed:0.11,green:0.10,blue:0.17,alpha:1), .bold, yTop: 40)
drawText("Drag the app onto the Applications folder", 14,
         NSColor(srgbRed:0.42,green:0.42,blue:0.5,alpha:1), .medium, yTop: 78)

// Arrow between the two icon slots (icons centered near y≈205 from top → middle band).
// Vertical center of icons (from top 205) → from bottom: H-205 = 195.
let yMid: CGFloat = H - 205
ctx.setStrokeColor(rgb(108,82,226))
ctx.setFillColor(rgb(108,82,226))
ctx.setLineWidth(12)
ctx.setLineCap(.round)
let x0: CGFloat = 258, x1: CGFloat = 402
ctx.beginPath()
ctx.move(to: CGPoint(x: x0, y: yMid))
ctx.addLine(to: CGPoint(x: x1, y: yMid))
ctx.strokePath()
// arrowhead
ctx.beginPath()
ctx.move(to: CGPoint(x: x1 + 18, y: yMid))
ctx.addLine(to: CGPoint(x: x1 - 8, y: yMid + 20))
ctx.addLine(to: CGPoint(x: x1 - 8, y: yMid - 20))
ctx.closePath(); ctx.fillPath()

img.unlockFocus()
guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError() }
try! png.write(to: URL(fileURLWithPath: "dmg_background.png"))
print("wrote dmg_background.png (\(Int(W))x\(Int(H)))")
