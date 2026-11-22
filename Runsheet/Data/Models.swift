import Foundation

// Bundled data, decoded from Resources/*.json. Shapes match the web app's data/ folder.
// Anything that can be null or missing in the files is optional here, so one gap never fails a whole file.

struct Category: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let group: String     // collectible, money, story, services
    let count: Int
}

struct Region: Codable, Hashable, Sendable {
    let name: String
    let x: Double
    let y: Double
}

struct Place: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let cat: String
    let x: Double
    let y: Double
    let area: String?
    let ch: Int?
    let source: String?
    let sources: Int?
    let license: String?
    let desc: String?
    let near: String?
    let slug: String?
    let wiki: String?
}

struct PlacesFile: Codable, Sendable {
    let source: String?
    let catHelp: [String: String]?
    let cats: [Category]
    let regions: [Region]
    let places: [Place]
}

struct Mission: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let ch: Int?
    let area: String?
}

struct SideMission: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let giver: String?
}

struct Cheat: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let unlock: String?
}

struct Trophy: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let how: String?
}

struct GuideFile: Codable, Sendable {
    let missions: [Mission]
    let side: [SideMission]
    let cheats: [Cheat]
    let trophies: [Trophy]
}

struct TonightItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let kind: String
    let ch: [Int]
    let who: String       // Jason, Lucia, any
    let time: String      // day, night, any
    let missable: Bool?
    let closes: String?
    let note: String?
    let sources: Int?
    let repeatable: Bool?
}

struct TonightFile: Codable, Sendable {
    let items: [TonightItem]
}

struct MoneyRule: Codable, Hashable, Sendable {
    let text: String
    let sources: Int?
}

struct MoneyMethod: Codable, Hashable, Sendable {
    let name: String
    let when: String?
    let note: String?
    let sources: Int?
    let cat: String?
}

struct MoneyFile: Codable, Sendable {
    let rules: [MoneyRule]
    let methods: [MoneyMethod]
}

/// GeoJSON FeatureCollection of land polygons in the same 0..1 space as places.
struct OutlineFile: Codable, Sendable {
    struct Feature: Codable, Sendable {
        struct Geometry: Codable, Sendable {
            let type: String
            let coordinates: [[[Double]]]
        }
        let geometry: Geometry
    }
    let features: [Feature]

    /// Each ring as a list of points.
    var rings: [[CGPoint]] {
        features.flatMap { f in
            f.geometry.coordinates.map { ring in ring.compactMap { $0.count >= 2 ? CGPoint(x: $0[0], y: $0[1]) : nil } }
        }
    }
}

/// Our own borders and labels on top of the map art, plus where the art tiles exist.
struct BasemapFile: Codable, Sendable {
    struct Tiles: Codable, Sendable {
        let minNativeZoom: Int
        let maxNativeZoom: Int
        let sea: String?
        let credit: String?
        let have: [String: String]?
    }
    struct Feature: Codable, Sendable {
        struct Props: Codable, Sendable { let k: String?; let name: String? }
        struct Geometry: Codable, Sendable { let type: String; let coordinates: [[Double]] }
        let properties: Props?
        let geometry: Geometry
    }
    struct Label: Codable, Sendable { let t: String; let k: String; let x: Double; let y: Double }
    let tiles: Tiles
    let features: [Feature]
    let labels: [Label]
}

struct GameData: Sendable {
    let source: String?
    let cats: [Category]
    let regions: [Region]
    let places: [Place]
    let guide: GuideFile
    let tonight: TonightFile
    let money: MoneyFile
    let rings: [[CGPoint]]
    let catHelp: [String: String]
    let basemap: BasemapFile?
    let borders: [[CGPoint]]
    let tileHave: [Int: Set<String>]

    let placesByCat: [String: [Place]]
    let placeByID: [String: Place]

    init(places p: PlacesFile, guide: GuideFile, tonight: TonightFile, money: MoneyFile, outline: OutlineFile, basemap: BasemapFile? = nil) {
        catHelp = p.catHelp ?? [:]
        self.basemap = basemap
        borders = (basemap?.features ?? []).filter { $0.properties?.k == "area" && $0.geometry.type == "LineString" }
            .map { $0.geometry.coordinates.compactMap { $0.count >= 2 ? CGPoint(x: $0[0], y: $0[1]) : nil } }
        var have: [Int: Set<String>] = [:]
        for (z, list) in basemap?.tiles.have ?? [:] { if let zi = Int(z) { have[zi] = Set(list.split(separator: " ").map(String.init)) } }
        tileHave = have
        source = p.source
        cats = p.cats
        regions = p.regions
        places = p.places
        self.guide = guide
        self.tonight = tonight
        self.money = money
        rings = outline.rings
        placesByCat = Dictionary(grouping: p.places, by: \.cat)
        placeByID = Dictionary(p.places.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    enum LoadError: Error { case missing(String) }

    static func loadBundled(from bundle: Bundle = .main) throws -> GameData {
        func read<T: Decodable>(_ name: String, as: T.Type) throws -> T {
            guard let url = bundle.url(forResource: name, withExtension: "json") else { throw LoadError.missing(name) }
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        }
        return GameData(
            places: try read("places", as: PlacesFile.self),
            guide: try read("guide", as: GuideFile.self),
            tonight: try read("tonight", as: TonightFile.self),
            money: try read("money", as: MoneyFile.self),
            outline: try read("outline", as: OutlineFile.self),
            basemap: try? read("basemap", as: BasemapFile.self))
    }

    func catName(_ id: String) -> String { cats.first { $0.id == id }?.name ?? id }
    func places(in cat: String) -> [Place] { placesByCat[cat] ?? [] }
    var collectibleCats: [Category] { cats.filter { $0.group == "collectible" } }
    var checklistCats: [Category] { cats.filter { $0.group == "collectible" || $0.group == "money" } }
    var viceCity: CGPoint {
        let r = regions.first { $0.name == "Vice City" } ?? regions.first
        return CGPoint(x: r?.x ?? 0.64, y: r?.y ?? 0.54)
    }
}

extension Place {
    var point: CGPoint { CGPoint(x: x, y: y) }
    /// "Near Crosstown, Vice City", or the area, or nothing.
    var whereText: String {
        let nearText = (near ?? "").replacingOccurrences(of: "Near ", with: "")
        var parts: [String] = []
        if let area, !area.isEmpty, !nearText.contains(area) { parts.append(area) }
        if !nearText.isEmpty { parts.append(nearText) }
        return parts.joined(separator: " · ")
    }
}

/// The map art is 2560 x 3313, and positions are shares of it, so y is stretched by this much.
let mapAspect: CGFloat = 3313.0 / 2560.0
