import SwiftUI

// The launch screen. Adapted from Alireza's gta6-countdown loading screen (MIT):
// same idea and timing, a neon line traces the shape, then colour rises from the bottom,
// with a monospaced LOADING percent. The countdown drew the game's logo; that is Rockstar's
// trademark, so here it traces our own Leonida outline and a route line instead.

private let neon = Color(UIColor(hex: 0xFF6B1A))
private let sunset = LinearGradient(
    colors: [Color(UIColor(hex: 0xFFC46B)), Color(UIColor(hex: 0xFF8A2B)), Color(UIColor(hex: 0xE8590C)), Color(UIColor(hex: 0xB8380A))],
    startPoint: .top, endPoint: .bottom)

/// Land polygons from outline.json as a Shape that fits itself, like an image would.
struct LeonidaShape: Shape {
    let rings: [[CGPoint]]

    func path(in rect: CGRect) -> Path {
        let all = rings.flatMap { $0 }
        guard let f = all.first else { return Path() }
        var box = CGRect(origin: f, size: .zero)
        for p in all { box = box.union(CGRect(origin: p, size: .zero)) }
        let s = min(rect.width / max(box.width, 0.001), rect.height / max(box.height, 0.001))
        let ox = rect.midX - box.midX * s, oy = rect.midY - box.midY * s
        var path = Path()
        // biggest rings first, so the trace starts on the mainland
        for ring in rings.sorted(by: { $0.count > $1.count }) where ring.count > 2 {
            path.move(to: CGPoint(x: ox + ring[0].x * s, y: oy + ring[0].y * s))
            for p in ring.dropFirst() { path.addLine(to: CGPoint(x: ox + p.x * s, y: oy + p.y * s)) }
            path.closeSubpath()
        }
        return path
    }
}

/// A route line with stops, drawn from an SVG path (parser from gta6-countdown).
private let routeMark = SVGShape("""
    M60,300 C120,250 110,190 170,170 S260,200 290,140 S330,60 400,50
    """, in: CGRect(x: 0, y: 0, width: 460, height: 360))

struct RunsheetMark: View {
    let rings: [[CGPoint]]
    var progress = 1.0

    var body: some View {
        let trace = min(progress * 2, 1)
        let fill = max(progress * 2 - 1, 0)
        ZStack {
            Group {
                LeonidaShape(rings: rings).trim(from: 0, to: trace).stroke(neon, lineWidth: 2)
                routeMark.trim(from: 0, to: trace).stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6]))
            }
            .shadow(color: neon, radius: 6)
            .opacity(1 - fill)

            Group {
                LeonidaShape(rings: rings).stroke(Color(UIColor(hex: 0x5A1A00)), lineWidth: 10)
                LeonidaShape(rings: rings).fill(sunset)
                LeonidaShape(rings: rings).stroke(Color(UIColor(hex: 0xFFD08A)), lineWidth: 2)
                routeMark.stroke(Color(UIColor(hex: 0x1C0A00)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                routeMark.stroke(.white, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            }
            .mask { Rectangle().scaleEffect(y: fill, anchor: .bottom) }
        }
        .frame(width: 300, height: 300)
    }
}

struct LoadingView: View {
    let rings: [[CGPoint]]
    let ready: Bool                 // data decoded
    var hold: Double? = nil          // for screenshots: freeze at this progress
    var onFinish: () -> Void

    @State private var progress = 0.0
    var loaded: Bool { progress >= 1 }

    var body: some View {
        VStack(spacing: 40) {
            RunsheetMark(rings: rings, progress: progress)
                .scaleEffect(loaded ? 1 : 0.92)
                .shadow(color: loaded ? neon.opacity(0.7) : .clear, radius: 30)

            VStack(spacing: 14) {
                Text("RUNSHEET")
                    .font(.system(size: 30, weight: .heavy).width(.expanded))
                    .kerning(6)
                    .opacity(loaded ? 1 : 0.85)
                if loaded {
                    Text("UNOFFICIAL GTA VI COMPANION")
                        .font(.footnote.bold()).kerning(3).foregroundStyle(.white.opacity(0.7))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text("LOADING \(Int(progress * 100))%")
                        .font(.footnote.bold().monospacedDigit())
                        .kerning(3)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            Text("Fan made. Not affiliated with Rockstar Games or Take-Two Interactive.")
                .font(.caption2).foregroundStyle(.gray).multilineTextAlignment(.center).padding(.horizontal, 24)
        }
        .background(.black)
        .animation(.spring(duration: 0.7, bounce: 0.35), value: loaded)
        .task {
            if let hold { progress = hold; return }
            while progress < 1 {
                try? await Task.sleep(for: .milliseconds(16))
                // don't pass 95% until the data is in
                let cap = ready ? 1.0 : 0.95
                progress = min(cap, progress + 0.011)
            }
            try? await Task.sleep(for: .milliseconds(650))
            onFinish()
        }
        .onChange(of: ready) { _, _ in }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Runsheet is loading")
    }
}
