import SwiftUI
import UIKit

// Map space: positions are shares (0..1) of the 2560 x 3313 map art, so on screen y is stretched by `mapAspect`.
// World units match the web app's Leaflet CRS: x * 1000 across, y * 1000 * aspect down. At "zoom" z one world
// unit is 2^z points, and the art tiles (256 px) follow the same grid.

struct MapCamera: Equatable {
    var scale: CGFloat = 600        // points per map width (= 1000 world units)
    var offset: CGPoint = .zero     // screen position of map (0,0)

    func toScreen(_ p: CGPoint) -> CGPoint { CGPoint(x: offset.x + p.x * scale, y: offset.y + p.y * scale * mapAspect) }
    func toMap(_ s: CGPoint) -> CGPoint { CGPoint(x: (s.x - offset.x) / scale, y: (s.y - offset.y) / (scale * mapAspect)) }

    /// Leaflet-style zoom level for this scale.
    var zoom: CGFloat { log2(scale / 1000) }

    static func fit(_ r: CGRect, in screen: CGRect, maxScale: CGFloat = .infinity) -> MapCamera {
        let w = max(r.width, 0.02), h = max(r.height * mapAspect, 0.02)
        let s = min(maxScale, min(screen.width / w, screen.height / h))
        return MapCamera(scale: s, offset: CGPoint(x: screen.midX - r.midX * s, y: screen.midY - r.midY * mapAspect * s))
    }

    static let minScale: CGFloat = 250     // zoom -2
    static let maxScale: CGFloat = 24000   // a bit past zoom 4, the sharpest art

    func zoomed(by k: CGFloat, around anchor: CGPoint) -> MapCamera {
        let s = min(MapCamera.maxScale, max(MapCamera.minScale, scale * k))
        let r = s / scale
        return MapCamera(scale: s, offset: CGPoint(x: anchor.x - (anchor.x - offset.x) * r, y: anchor.y - (anchor.y - offset.y) * r))
    }

    func centered(on p: CGPoint, in size: CGSize, scale s: CGFloat, yBias: CGFloat = 0.42) -> MapCamera {
        MapCamera(scale: s, offset: CGPoint(x: size.width / 2 - p.x * s, y: size.height * yBias - p.y * s * mapAspect))
    }

    /// All of Leonida, like the web app's first view.
    static let island = CGRect(x: 0.13, y: 0.13, width: 0.77, height: 0.79)
}

// MARK: tiles

/// Loads map art tiles from the bundle off the main thread and keeps the recent ones.
@MainActor @Observable
final class TileStore {
    static let shared = TileStore()
    private(set) var version = 0
    @ObservationIgnored private var images: [String: Image] = [:]
    @ObservationIgnored private var order: [String] = []
    @ObservationIgnored private var pending: Set<String> = []
    @ObservationIgnored private let root = Bundle.main.resourceURL?.appendingPathComponent("tiles")
    @ObservationIgnored private let limit = 180

    init() {
        // the coarse levels are tiny and always on hand, so there is never a blank map
        for z in -2...0 {
            let k = pow(2.0, Double(z))
            for x in 0...Int(k * 1000 / 256) { for y in 0...Int(k * 1294.2 / 256) { load(z, x, y, sync: true) } }
        }
    }

    func image(_ z: Int, _ x: Int, _ y: Int) -> Image? {
        let key = "\(z)/\(x)_\(y)"
        if let img = images[key] { return img }
        load(z, x, y, sync: false)
        return nil
    }

    private func load(_ z: Int, _ x: Int, _ y: Int, sync: Bool) {
        let key = "\(z)/\(x)_\(y)"
        guard images[key] == nil, !pending.contains(key), let url = root?.appendingPathComponent("\(key).webp") else { return }
        if sync {
            if let ui = UIImage(contentsOfFile: url.path) { store(key, ui) }
            return
        }
        pending.insert(key)
        Task.detached(priority: .userInitiated) {
            let ui = UIImage(contentsOfFile: url.path)?.preparingForDisplay()
            await MainActor.run {
                self.pending.remove(key)
                if let ui { self.store(key, ui); self.version &+= 1 }
            }
        }
    }

    private func store(_ key: String, _ ui: UIImage) {
        images[key] = Image(uiImage: ui)
        order.append(key)
        // keep levels 0 and below forever; drop the oldest sharp tiles past the limit
        while order.count > limit, let i = order.firstIndex(where: { !$0.hasPrefix("-") && !$0.hasPrefix("0/") }) {
            images[order.remove(at: i)] = nil
        }
    }
}

// MARK: marks

struct MapPin: Equatable {
    let id: String
    let cat: String
    let point: CGPoint
    let color: Color
    let found: Bool
}

struct MapCluster: Equatable {
    let key: String
    let point: CGPoint
    let count: Int
    let bounds: CGRect
}

enum PinGrouping {
    /// Below the closest zoom, or on a crowded screen, close pins become one numbered bubble (64 pt cells on a
    /// fixed world grid, so bubbles don't jump while panning). Same rule as the web app.
    static func group(_ places: [Place], camera: MapCamera, size: CGSize) -> (pins: [Place], clusters: [MapCluster]) {
        let a = camera.toMap(CGPoint(x: -40, y: -40)), b = camera.toMap(CGPoint(x: size.width + 40, y: size.height + 40))
        let view = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
        let inView = places.filter { view.contains($0.point) }
        let z = camera.zoom.rounded()
        if z >= 4 || (z >= 2 && inView.count <= 250) { return (inView, []) }
        let px = pow(2, z)  // points per world unit at this zoom
        var cells: [String: [Place]] = [:]
        var keys: [String] = []
        for p in inView {
            let k = "\(Int(floor(p.x * 1000 * px / 64)))_\(Int(floor(p.y * 1000 * mapAspect * px / 64)))"
            if cells[k] == nil { keys.append(k) }
            cells[k, default: []].append(p)
        }
        var pins: [Place] = [], clusters: [MapCluster] = []
        for k in keys {
            let g = cells[k]!
            if g.count == 1 { pins.append(g[0]); continue }
            let cx = g.reduce(0.0) { $0 + $1.x } / Double(g.count)
            let cy = g.reduce(0.0) { $0 + $1.y } / Double(g.count)
            var r = CGRect(origin: g[0].point, size: .zero)
            for p in g { r = r.union(CGRect(origin: p.point, size: .zero)) }
            clusters.append(MapCluster(key: k, point: CGPoint(x: cx, y: cy), count: g.count, bounds: r))
        }
        return (pins, clusters)
    }

    static func bubbleSize(_ n: Int) -> CGFloat { n < 10 ? 34 : n < 50 ? 38 : n < 200 ? 44 : 50 }
}

private let labelZoom: [String: ClosedRange<CGFloat>] = [
    "sea": 0...9, "region": -2...1, "area": 1...9, "water": 1...9, "town": 2...9, "peak": 2...9, "district": 2...9, "poi": 3...9,
]

// MARK: drawing

/// The drawing itself. Animatable, so camera moves and the route draw animate frame by frame.
struct MapCanvas: View, Animatable {
    var camera: MapCamera
    var routeDraw: CGFloat              // 0..1, how much of the route line is drawn
    let data: GameData
    var pins: [MapPin] = []
    var clusters: [MapCluster] = []
    var waypoint: CGPoint?
    var route: [CGPoint] = []
    var routeDone = 0
    var routeCurrent: Int? = nil
    var selected: String? = nil
    var hideLabelKinds: Set<String> = []
    var tileVersion = 0                 // changes when new tiles arrive, so the canvas redraws

    nonisolated var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(.init(camera.scale, routeDraw), .init(camera.offset.x, camera.offset.y)) }
        set {
            camera.scale = newValue.first.first
            routeDraw = newValue.first.second
            camera.offset = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let tiles = TileStore.shared
        let sea = Color(UIColor(hex: 0x2F90AF))
        let version = tileVersion
        Canvas(rendersAsynchronously: false) { ctx, size in
            _ = version
            let cam = camera
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(sea))

            // map art: a coarse layer that is always loaded, then the sharp layer for this zoom
            let have = data.tileHave
            let want = Int(min(4, max(-2, ceil(log2(cam.scale / 1000 * displayScale) - 0.3))))
            for z in Array(Set([min(0, want), want])).sorted() {
                let t = 256 / pow(2, CGFloat(z))           // world units per tile
                let tp = t * cam.scale / 1000              // points per tile
                let maxX = Int(ceil(1000 / t)) - 1, maxY = Int(ceil(1294.2 / t)) - 1
                let x0 = max(0, Int(floor(-cam.offset.x / tp))), x1 = min(maxX, Int(floor((size.width - cam.offset.x) / tp)))
                let y0 = max(0, Int(floor(-cam.offset.y / tp))), y1 = min(maxY, Int(floor((size.height - cam.offset.y) / tp)))
                guard x0 <= x1, y0 <= y1 else { continue }
                for x in x0...x1 {
                    for y in y0...y1 {
                        if z >= 1, let set = have[z], !set.contains("\(x)_\(y)") { continue }  // open sea, never written
                        guard let img = tiles.image(z, x, y) else { continue }
                        // a hair of overlap hides seams between tiles
                        let r = CGRect(x: cam.offset.x + CGFloat(x) * tp, y: cam.offset.y + CGFloat(y) * tp, width: tp + 0.6, height: tp + 0.6)
                        ctx.draw(img, in: r)
                    }
                }
            }

            let zoom = cam.zoom

            // our own area borders, dashed, from zoom 1
            if zoom >= 0.8 {
                var b = Path()
                for line in data.borders where line.count > 1 {
                    b.move(to: cam.toScreen(line[0]))
                    for p in line.dropFirst() { b.addLine(to: cam.toScreen(p)) }
                }
                ctx.stroke(b, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 1.4, dash: [5, 5]))
            }

            // route
            if route.count > 1 {
                let pts = route.map(cam.toScreen)
                if routeDone > 0 {
                    var donePath = Path()
                    donePath.addLines(Array(pts.prefix(routeDone + 1)))
                    ctx.stroke(donePath, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                var todo = Path()
                todo.addLines(Array(pts.dropFirst(max(0, routeDone))))
                let drawn = todo.trimmedPath(from: 0, to: routeDraw)
                ctx.stroke(drawn, with: .color(.white), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                ctx.stroke(drawn, with: .color(RS.accent), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            for (i, p) in route.enumerated() {
                let s = cam.toScreen(p)
                let cur = i == routeCurrent, past = i < routeDone
                let reveal = route.count < 2 ? 1 : CGFloat(i) / CGFloat(route.count - 1)
                guard past || reveal <= routeDraw + 0.001 else { continue }
                let r: CGFloat = cur ? 9 : 5.5
                let rect = CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(cur ? RS.accent : .white))
                ctx.stroke(Path(ellipseIn: rect), with: .color(cur ? .white : (past ? .gray : RS.accent)), lineWidth: cur ? 3 : 2)
            }

            // pin bubbles, under the labels
            for c in clusters {
                let s = cam.toScreen(c.point)
                let d = PinGrouping.bubbleSize(c.count)
                let rect = CGRect(x: s.x - d / 2, y: s.y - d / 2, width: d, height: d)
                ctx.fill(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(.white))
                ctx.fill(Path(ellipseIn: rect), with: .color(RS.accent))
                ctx.draw(Text("\(c.count)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white), at: s)
            }

            // pins: a coloured disc with the category icon
            let pinR: CGFloat = zoom > 2.5 ? 12 : 10
            var icons: [String: GraphicsContext.ResolvedImage] = [:]
            for pin in pins {
                let s = cam.toScreen(pin.point)
                guard s.x > -20, s.x < size.width + 20, s.y > -20, s.y < size.height + 20 else { continue }
                let sel = pin.id == selected
                let r = sel ? pinR + 3 : pinR
                let rect = CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2)
                var c = ctx
                c.opacity = pin.found ? 0.55 : 1
                c.fill(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(.white))
                c.fill(Path(ellipseIn: rect), with: .color(pin.color))
                let symbol = pin.found ? "checkmark" : CatIcon.name(pin.cat)
                if icons[symbol] == nil {
                    var img = ctx.resolve(Image(systemName: symbol))
                    img.shading = .color(.white)
                    icons[symbol] = img
                }
                if let img = icons[symbol] {
                    let isz = img.size, k = (r * 1.05) / max(isz.width, isz.height)
                    c.draw(img, in: CGRect(x: s.x - isz.width * k / 2, y: s.y - isz.height * k / 2, width: isz.width * k, height: isz.height * k))
                }
                if sel { ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -6, dy: -6)), with: .color(.white), lineWidth: 3) }
            }

            // labels on top, with a dark halo so they read on the art
            ctx.drawLayer { l in
                l.addFilter(.shadow(color: .black.opacity(0.75), radius: 2.5))
                for lb in data.basemap?.labels ?? [] {
                    guard let range = labelZoom[lb.k], range.contains(zoom.rounded()), !hideLabelKinds.contains(lb.k) else { continue }
                    let s = cam.toScreen(CGPoint(x: lb.x, y: lb.y))
                    guard s.x > -150, s.x < size.width + 150, s.y > -30, s.y < size.height + 30 else { continue }
                    l.draw(Self.labelText(lb), at: s)
                }
            }

            // waypoint ring
            if let w = waypoint {
                let s = cam.toScreen(w)
                ctx.stroke(Path(ellipseIn: CGRect(x: s.x - 17, y: s.y - 17, width: 34, height: 34)), with: .color(RS.accent), lineWidth: 3)
            }
        }
        .accessibilityLabel("Map of Leonida")
    }

    private static func labelText(_ l: BasemapFile.Label) -> Text {
        switch l.k {
        case "region": Text(l.t.uppercased()).font(.system(size: 13, weight: .heavy)).kerning(1.6).foregroundStyle(.white)
        case "sea": Text(l.t).font(.system(size: 13, weight: .semibold).italic()).foregroundStyle(.white.opacity(0.9))
        case "area": Text(l.t.uppercased()).font(.system(size: 11, weight: .bold)).kerning(1.2).foregroundStyle(.white)
        case "water": Text(l.t).font(.system(size: 11, weight: .medium).italic()).foregroundStyle(Color(UIColor(hex: 0xD6F1FF)))
        case "town", "district": Text(l.t).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
        case "peak": Text("▲ " + l.t).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.9))
        default: Text(l.t).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.9))
        }
    }
}

/// Pinch, pan, tap and double-tap on top of the canvas.
struct MapGestures: ViewModifier {
    @Binding var camera: MapCamera
    var onTap: (CGPoint) -> Void
    var onMoveEnd: () -> Void = {}

    @State private var startCam: MapCamera?
    @State private var pinching = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2).onEnded { v in
                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) { camera = camera.zoomed(by: 2, around: v.location) }
                    onMoveEnd()
                }
                .exclusively(before: SpatialTapGesture().onEnded { v in onTap(v.location) })
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { v in
                        guard !pinching else { return }
                        let base = startCam ?? camera
                        if startCam == nil { startCam = camera }
                        camera.offset = CGPoint(x: base.offset.x + v.translation.width, y: base.offset.y + v.translation.height)
                    }
                    .onEnded { v in
                        defer { startCam = nil; onMoveEnd() }
                        guard !pinching else { return }
                        let dx = v.predictedEndTranslation.width - v.translation.width
                        let dy = v.predictedEndTranslation.height - v.translation.height
                        withAnimation(.spring(duration: 0.5, bounce: 0)) {
                            camera.offset = CGPoint(x: camera.offset.x + dx * 0.35, y: camera.offset.y + dy * 0.35)
                        }
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if !pinching { pinching = true; startCam = camera }
                        guard let base = startCam else { return }
                        camera = base.zoomed(by: v.magnification, around: v.startLocation)
                    }
                    .onEnded { _ in pinching = false; startCam = nil; onMoveEnd() }
            )
    }
}
