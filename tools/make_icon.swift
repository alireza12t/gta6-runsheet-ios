// Draws the app icon: Leonida outline on a sunset gradient with a dashed route. Run: swift tools/make_icon.swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let outline = try! JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Runsheet/Resources/outline.json"))) as! [String: Any]
var rings: [[CGPoint]] = []
for f in outline["features"] as! [[String: Any]] {
    let g = f["geometry"] as! [String: Any]
    for ring in g["coordinates"] as! [[[Double]]] { rings.append(ring.map { CGPoint(x: $0[0], y: $0[1]) }) }
}
let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func c(_ h: UInt32) -> CGColor { CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1) }
let grad = CGGradient(colorsSpace: cs, colors: [c(0x1C0A00), c(0x3A1405), c(0x7A2A08)] as CFArray, locations: [0, 0.6, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
// fit rings
let all = rings.flatMap { $0 }
let minX = all.map(\.x).min()!, maxX = all.map(\.x).max()!, minY = all.map(\.y).min()!, maxY = all.map(\.y).max()!
let box = S * 0.74
let sc = min(box / (maxX - minX), box / (maxY - minY))
let ox = S / 2 - (minX + maxX) / 2 * sc, oy = S / 2 - (minY + maxY) / 2 * sc
func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: ox + p.x * sc, y: S - (oy + p.y * sc)) }
let land = CGMutablePath()
for r in rings where r.count > 2 { land.move(to: pt(r[0])); for p in r.dropFirst() { land.addLine(to: pt(p)) }; land.closeSubpath() }
ctx.saveGState(); ctx.addPath(land); ctx.clip()
let sun = CGGradient(colorsSpace: cs, colors: [c(0xFFC46B), c(0xFF8A2B), c(0xE8590C), c(0xB8380A)] as CFArray, locations: [0, 0.35, 0.7, 1])!
ctx.drawLinearGradient(sun, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()
ctx.addPath(land); ctx.setStrokeColor(c(0xFFD08A)); ctx.setLineWidth(6); ctx.strokePath()
// route
let route = CGMutablePath()
let a = CGPoint(x: S * 0.30, y: S * 0.30), b = CGPoint(x: S * 0.70, y: S * 0.72)
route.move(to: a)
route.addCurve(to: b, control1: CGPoint(x: S * 0.62, y: S * 0.30), control2: CGPoint(x: S * 0.38, y: S * 0.72))
ctx.addPath(route); ctx.setStrokeColor(c(0x1C0A00)); ctx.setLineWidth(40); ctx.setLineCap(.round); ctx.strokePath()
ctx.addPath(route); ctx.setStrokeColor(c(0xFFFFFF)); ctx.setLineWidth(18); ctx.setLineDash(phase: 0, lengths: [36, 30]); ctx.strokePath()
ctx.setLineDash(phase: 0, lengths: [])
for (p, r) in [(a, CGFloat(40)), (b, CGFloat(52))] {
    ctx.setFillColor(c(0x1C0A00)); ctx.fillEllipse(in: CGRect(x: p.x - r - 10, y: p.y - r - 10, width: (r + 10) * 2, height: (r + 10) * 2))
    ctx.setFillColor(c(0xFFFFFF)); ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
}
let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Runsheet/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"))
print("icon written")
