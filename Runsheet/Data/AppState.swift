import Foundation

/// Everything the player changes. Saved as one JSON file on the device. No accounts, no backend.
struct AppState: Codable, Equatable, Sendable {
    var chapter = 1
    var who = "Lucia"
    var time = "night"
    var mins = 40
    var routeCat = "stunt-jumps"
    var theme = ThemeChoice.auto
    var found: [String: Date] = [:]
    var done: [String: Date] = [:]
    var waypoint: String?
    var mapCats: [String] = ["stunt-jumps"]
    var hideFound = false
    var run: RunPlan?

    // Tolerant decoding: a field missing from an older file keeps its default.
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppState()
        chapter = (try? c.decode(Int.self, forKey: .chapter)) ?? d.chapter
        who = (try? c.decode(String.self, forKey: .who)) ?? d.who
        time = (try? c.decode(String.self, forKey: .time)) ?? d.time
        mins = (try? c.decode(Int.self, forKey: .mins)) ?? d.mins
        routeCat = (try? c.decode(String.self, forKey: .routeCat)) ?? d.routeCat
        theme = (try? c.decode(ThemeChoice.self, forKey: .theme)) ?? d.theme
        found = (try? c.decode([String: Date].self, forKey: .found)) ?? d.found
        done = (try? c.decode([String: Date].self, forKey: .done)) ?? d.done
        waypoint = try? c.decodeIfPresent(String.self, forKey: .waypoint)
        mapCats = (try? c.decode([String].self, forKey: .mapCats)) ?? d.mapCats
        hideFound = (try? c.decode(Bool.self, forKey: .hideFound)) ?? d.hideFound
        run = try? c.decodeIfPresent(RunPlan.self, forKey: .run)
    }
}

enum ThemeChoice: String, Codable, CaseIterable, Sendable {
    case auto, light, dark
    var next: ThemeChoice { switch self { case .auto: .light; case .light: .dark; case .dark: .auto } }
    var symbol: String { switch self { case .auto: "circle.lefthalf.filled"; case .light: "sun.max.fill"; case .dark: "moon.fill" } }
}

struct RunStop: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable { case task, place }
    var kind: Kind
    var id: String
    var name: String
    var sub: String?
    var tag: String?
    var status: BoardStatus?
    var repeatable = false
    var x: Double?
    var y: Double?
    var cat: String?

    var point: CGPoint? { if let x, let y { CGPoint(x: x, y: y) } else { nil } }
}

struct RunPlan: Codable, Hashable, Sendable {
    var title: String
    var stops: [RunStop]
    var idx = 0

    var total: Int { stops.count }
    var isComplete: Bool { idx >= stops.count }
    var current: RunStop? { idx < stops.count ? stops[idx] : nil }
}

enum BoardStatus: String, Codable, Sendable {
    case closing, live, ready, money
    var order: Double { switch self { case .closing: 0; case .live: 1; case .ready: 2; case .money: 3 } }
}

struct BoardItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let sub: String
    let status: BoardStatus
    let label: String
    let order: Double
    let sources: Int
    var isRoute = false
    var repeatable = false
}
