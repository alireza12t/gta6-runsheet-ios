import CoreGraphics

/// Route solver: nearest neighbour, then open-path 2-opt to remove crossings.
/// Straight-line map distance only. It suggests an order, not a drive time.
/// Ported from the web app's route.js.
enum Route {
    static func dist(_ a: CGPoint, _ b: CGPoint) -> Double { Double(hypot(a.x - b.x, a.y - b.y)) }

    static func tour<T>(_ items: [T], start: CGPoint?, point: (T) -> CGPoint) -> [T] {
        guard !items.isEmpty else { return [] }
        var rest = items
        var first = 0
        if let start {
            var best = Double.infinity
            for (i, p) in rest.enumerated() {
                let v = dist(point(p), start)
                if v < best { best = v; first = i }
            }
        }
        var path = [rest.remove(at: first)]
        while !rest.isEmpty {
            let last = point(path[path.count - 1])
            var j = 0, best = Double.infinity
            for (i, p) in rest.enumerated() {
                let v = dist(point(p), last)
                if v < best { best = v; j = i }
            }
            path.append(rest.remove(at: j))
        }
        // open-path 2-opt; keep the first stop fixed
        var improved = true, guardCount = 0
        while improved && guardCount < 50 {
            guardCount += 1
            improved = false
            if path.count < 4 { break }
            for i in 1..<(path.count - 2) {
                for k in (i + 1)..<(path.count - 1) {
                    let a = point(path[i - 1]), b = point(path[i]), c = point(path[k]), d = point(path[k + 1])
                    let delta = dist(a, c) + dist(b, d) - dist(a, b) - dist(c, d)
                    if delta < -1e-9 {
                        path[i...k].reverse()
                        improved = true
                    }
                }
            }
        }
        return path
    }

    /// Pick the n points closest to a start point, then order them.
    static func nearestSet<T>(_ items: [T], start: CGPoint, count n: Int, point: (T) -> CGPoint) -> [T] {
        let sorted = items.sorted { dist(point($0), start) < dist(point($1), start) }
        return tour(Array(sorted.prefix(n)), start: start, point: point)
    }

    static func length(_ pts: [CGPoint]) -> Double {
        zip(pts, pts.dropFirst()).reduce(0) { $0 + dist($1.0, $1.1) }
    }
}
