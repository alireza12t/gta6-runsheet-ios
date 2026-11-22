import SwiftUI

/// Camera for our own map. Map space is the data's 0..1 square; `scale` is points per map unit.
struct MapCamera: Equatable {
    var scale: CGFloat = 600
    var offset: CGPoint = .zero  // screen position of map (0,0)

    func toScreen(_ p: CGPoint) -> CGPoint { CGPoint(x: offset.x + p.x * scale, y: offset.y + p.y * scale) }
    func toMap(_ s: CGPoint) -> CGPoint { CGPoint(x: (s.x - offset.x) / scale, y: (s.y - offset.y) / scale) }

    /// Fit a map rect into a screen rect.
    static func fit(_ r: CGRect, in screen: CGRect, maxScale: CGFloat = .infinity) -> MapCamera {
        let w = max(r.width, 0.02), h = max(r.height, 0.02)
        let s = min(maxScale, min(screen.width / w, screen.height / h))
        return MapCamera(scale: s, offset: CGPoint(x: screen.midX - r.midX * s, y: screen.midY - r.midY * s))
    }

    static let minScale: CGFloat = 250
    static let maxScale: CGFloat = 9000
}

struct MapPin: Equatable {
    let id: String
    let point: CGPoint
    let color: Color
    let found: Bool
}

/// The drawing itself. Animatable, so camera moves and the route draw animate frame by frame.
struct MapCanvas: View, Animatable {
    var camera: MapCamera
    var routeDraw: CGFloat              // 0..1, how much of the route line is drawn
    let rings: [[CGPoint]]
    let regions: [Region]
    let pins: [MapPin]
    var waypoint: CGPoint?
    var route: [CGPoint] = []
    var routeDone = 0                   // stops of the route already done
    var routeCurrent: Int? = nil
    var selected: String? = nil

    nonisolated var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(.init(camera.scale, routeDraw), .init(camera.offset.x, camera.offset.y)) }
        set {
            camera.scale = newValue.first.first
            routeDraw = newValue.first.second
            camera.offset = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let cam = camera
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(RS.sea))

            // land: thick shallow-water halo, then land fill
            var land = Path()
            for ring in rings where ring.count > 2 {
                land.move(to: cam.toScreen(ring[0]))
                for p in ring.dropFirst() { land.addLine(to: cam.toScreen(p)) }
                land.closeSubpath()
            }
            let halo = max(6, min(26, cam.scale * 0.018))
            ctx.stroke(land, with: .color(RS.shallow), style: StrokeStyle(lineWidth: halo, lineJoin: .round))
            ctx.fill(land, with: .color(RS.land))
            ctx.stroke(land, with: .color(RS.inland), lineWidth: 1)

            // region labels
            for r in regions {
                let s = cam.toScreen(CGPoint(x: r.x, y: r.y))
                guard s.x > -200, s.x < size.width + 200, s.y > -40, s.y < size.height + 40 else { continue }
                let t = Text(r.name.uppercased()).font(.system(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(RS.label)
                ctx.draw(t, at: s)
            }

            // route
            if route.count > 1 {
                let pts = route.map(cam.toScreen)
                if routeDone > 0 {
                    var donePath = Path()
                    donePath.addLines(Array(pts.prefix(routeDone + 1)))
                    ctx.stroke(donePath, with: .color(RS.text3), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                var todo = Path()
                todo.addLines(Array(pts.dropFirst(max(0, routeDone))))
                let drawn = todo.trimmedPath(from: 0, to: routeDraw)
                ctx.stroke(drawn, with: .color(RS.card), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                ctx.stroke(drawn, with: .color(RS.accent), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            if !route.isEmpty {
                for (i, p) in route.enumerated() {
                    let s = cam.toScreen(p)
                    let cur = i == routeCurrent, past = i < routeDone
                    let reveal = route.count < 2 ? 1 : CGFloat(i) / CGFloat(route.count - 1)
                    guard past || reveal <= routeDraw + 0.001 else { continue }
                    let r: CGFloat = cur ? 9 : 5.5
                    let rect = CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(cur ? RS.accent : RS.card))
                    ctx.stroke(Path(ellipseIn: rect), with: .color(cur ? RS.card : (past ? RS.text3 : RS.accent)), lineWidth: cur ? 3 : 2)
                }
            }

            // pins
            let pinR: CGFloat = cam.scale > 2500 ? 8 : 6.5
            for pin in pins {
                let s = cam.toScreen(pin.point)
                guard s.x > -20, s.x < size.width + 20, s.y > -20, s.y < size.height + 20 else { continue }
                let sel = pin.id == selected
                let r = sel ? pinR + 3 : pinR
                let rect = CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2)
                var c = ctx
                c.opacity = pin.found ? 0.4 : 1
                c.fill(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(RS.pinRing))
                c.fill(Path(ellipseIn: rect), with: .color(pin.color))
                if pin.found {
                    var tick = Path()
                    tick.move(to: CGPoint(x: s.x - r * 0.45, y: s.y))
                    tick.addLine(to: CGPoint(x: s.x - r * 0.1, y: s.y + r * 0.38))
                    tick.addLine(to: CGPoint(x: s.x + r * 0.5, y: s.y - r * 0.4))
                    c.stroke(tick, with: .color(.white), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            }

            // waypoint ring
            if let w = waypoint {
                let s = cam.toScreen(w)
                let rect = CGRect(x: s.x - 15, y: s.y - 15, width: 30, height: 30)
                ctx.stroke(Path(ellipseIn: rect), with: .color(RS.accent), lineWidth: 3)
            }
        }
        .accessibilityLabel("Map of Leonida")
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
                        // a little momentum
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

extension MapCamera {
    func zoomed(by k: CGFloat, around anchor: CGPoint) -> MapCamera {
        let s = min(MapCamera.maxScale, max(MapCamera.minScale, scale * k))
        let r = s / scale
        return MapCamera(scale: s, offset: CGPoint(x: anchor.x - (anchor.x - offset.x) * r, y: anchor.y - (anchor.y - offset.y) * r))
    }

    func centered(on p: CGPoint, in size: CGSize, scale s: CGFloat, yBias: CGFloat = 0.42) -> MapCamera {
        MapCamera(scale: s, offset: CGPoint(x: size.width / 2 - p.x * s, y: size.height * yBias - p.y * s))
    }
}
