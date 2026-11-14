// Génère Resources/icon.icns : swift tools/make_icon.swift <dossier-sortie>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconset = out + "/icon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Fond : carré arrondi macOS avec marge, dégradé bleu -> indigo.
    let inset = s * 0.055
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = CGPath(roundedRect: rect, cornerWidth: s * 0.225, cornerHeight: s * 0.225, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03,
                  color: NSColor.black.withAlphaComponent(0.25).cgColor)
    ctx.addPath(path); ctx.setFillColor(NSColor.white.cgColor); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [NSColor(red: 0.20, green: 0.55, blue: 1.0, alpha: 1).cgColor,
                                   NSColor(red: 0.30, green: 0.25, blue: 0.85, alpha: 1).cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    // Barres de statistiques.
    let heights: [CGFloat] = [0.26, 0.40, 0.33, 0.52, 0.68]
    let barW = s * 0.095
    let gap = s * 0.045
    let total = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
    let x0 = (s - total) / 2
    let base = s * 0.25
    for (i, h) in heights.enumerated() {
        let r = CGRect(x: x0 + CGFloat(i) * (barW + gap), y: base, width: barW, height: s * h * 0.78)
        let p = CGPath(roundedRect: r, cornerWidth: barW * 0.3, cornerHeight: barW * 0.3, transform: nil)
        ctx.addPath(p)
        ctx.setFillColor(NSColor.white.withAlphaComponent(i == heights.count - 1 ? 1.0 : 0.82).cgColor)
        ctx.fillPath()
    }
    // Courbe de tendance orange.
    ctx.setStrokeColor(NSColor(red: 1.0, green: 0.74, blue: 0.2, alpha: 1).cgColor)
    ctx.setLineWidth(s * 0.028)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    let pts: [CGPoint] = heights.enumerated().map { i, h in
        CGPoint(x: x0 + CGFloat(i) * (barW + gap) + barW / 2, y: base + s * h * 0.78 + s * 0.07)
    }
    ctx.move(to: pts[0])
    for p in pts.dropFirst() { ctx.addLine(to: p) }
    ctx.strokePath()
    for p in pts {
        ctx.setFillColor(NSColor(red: 1.0, green: 0.74, blue: 0.2, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - s * 0.02, y: p.y - s * 0.02, width: s * 0.04, height: s * 0.04))
    }
    ctx.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    try! render(px).write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}
try! render(1024).write(to: URL(fileURLWithPath: out + "/icon-1024.png"))
