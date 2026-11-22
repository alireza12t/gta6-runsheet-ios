import Foundation
import Observation
import SwiftUI

enum AppTab: String, Hashable, CaseIterable { case plan, map, guide, checklist }

/// App-wide state. Game data is read-only from the bundle; progress lives in `state`
/// and is written to a JSON file in Application Support after every change.
@MainActor @Observable
final class Store {
    private(set) var data: GameData?
    private(set) var loadError: String?

    var state: AppState { didSet { if state != oldValue { save(); if state.run != oldValue.run { syncLiveActivity() } } } }

    // UI routing, not persisted
    var tab: AppTab = .plan
    var checklistCat: String?
    var showRun = false
    var runSource = "plan"
    var mapFocus: String?
    var toast: String?

    private let fileURL: URL
    private let persist: Bool

    init(persist: Bool = true, fileURL: URL? = nil) {
        self.persist = persist
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let folder = dir.appendingPathComponent("Runsheet", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = fileURL ?? folder.appendingPathComponent("state.json")
        self.state = persist ? Store.readState(at: self.fileURL) : AppState()
        // The bundled data is small (about 140 KB), so read it right away.
        do { data = try GameData.loadBundled() } catch { loadError = String(describing: error) }
    }

    func setData(_ d: GameData) { data = d }

    // MARK: persistence

    /// Never crash on a bad file: move it aside (never delete) and start fresh.
    private static func readState(at url: URL) -> AppState {
        guard let raw = try? Data(contentsOf: url) else { return AppState() }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .millisecondsSince1970
        if let s = try? dec.decode(AppState.self, from: raw) { return s }
        let aside = url.deletingLastPathComponent()
            .appendingPathComponent("state-unreadable-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url, to: aside)
        return AppState()
    }

    private func save() {
        guard persist else { return }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .millisecondsSince1970
        if let raw = try? enc.encode(state) {
            try? raw.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    func resetProgress() {
        var s = AppState()
        s.theme = state.theme
        state = s
    }

    // MARK: progress

    func isFound(_ id: String) -> Bool { state.found[id] != nil }
    func isDone(_ id: String) -> Bool { state.done[id] != nil }

    func foundCount(_ cat: String) -> Int { data?.places(in: cat).filter { state.found[$0.id] != nil }.count ?? 0 }

    @discardableResult
    func toggleFound(_ id: String) -> Bool {
        if state.found[id] != nil { state.found[id] = nil; return false }
        state.found[id] = Date()
        return true
    }

    func toggleDone(_ id: String) {
        if state.done[id] != nil { state.done[id] = nil } else { state.done[id] = Date() }
    }

    func flash(_ msg: String) {
        toast = msg
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            if self?.toast == msg { self?.toast = nil }
        }
    }

    // MARK: plan board (rules ported from app.js boardItems)

    func boardItems() -> [BoardItem] {
        guard let data else { return [] }
        let s = state
        var items: [BoardItem] = []
        for t in data.tonight.items {
            if s.done[t.id] != nil { continue }
            if !t.ch.contains(s.chapter) { continue }
            if t.who != "any" && t.who != s.who { continue }
            if t.time != "any" && t.time != s.time { continue }
            var status = BoardStatus.ready, label = "READY"
            if t.missable == true { status = .closing; label = "CLOSING" }
            else if t.time != "any" || t.who != "any" { status = .live; label = "LIVE NOW" }
            if t.kind == "money" { status = .money; label = "MONEY" }
            let sub: String
            if t.missable == true, let closes = t.closes { sub = "Gone " + closes } else { sub = t.note ?? "" }
            items.append(BoardItem(id: t.id, name: t.name, sub: sub, status: status, label: label,
                                   order: status.order, sources: t.sources ?? 0, repeatable: t.repeatable ?? false))
        }
        let rc = s.routeCat
        let left = data.places(in: rc).count - foundCount(rc)
        if left > 0 {
            items.append(BoardItem(id: "route", name: data.catName(rc), sub: "\(left) left on the map", status: .ready,
                                   label: "ROUTE", order: 2.5, sources: 1, isRoute: true))
        }
        items.append(BoardItem(id: "cash", name: "Store hold-up, then bank it", sub: "Carried cash is lost if you are busted",
                               status: .money, label: "MONEY", order: 4, sources: 2))
        return items.enumerated().sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }.map(\.element)
    }

    func startPoint() -> CGPoint {
        if let w = state.waypoint, let p = data?.placeByID[w] { return p.point }
        return data?.viceCity ?? CGPoint(x: 0.64, y: 0.54)
    }

    static let stopsForMinutes = [20: 5, 40: 10, 60: 15, 90: 22]

    /// Build a run. With `places`, routes exactly those (checklist, map). Without, uses the plan board.
    func buildRun(places override: [Place]? = nil, title: String? = nil, from: CGPoint? = nil, source: String = "plan") {
        guard let data else { return }
        var stops: [RunStop] = []
        if override == nil {
            for t in boardItems() where !t.isRoute && t.status != .money {
                stops.append(RunStop(kind: .task, id: t.id, name: t.name, sub: t.sub, tag: t.label, status: t.status, repeatable: t.repeatable))
            }
        }
        let pool = override ?? data.places(in: state.routeCat).filter { state.found[$0.id] == nil }
        let n = override != nil ? pool.count : (Store.stopsForMinutes[state.mins] ?? 10)
        let path = Route.nearestSet(pool, start: from ?? startPoint(), count: n, point: \.point)
        for p in path {
            stops.append(RunStop(kind: .place, id: p.id, name: p.name, sub: data.catName(p.cat), x: p.x, y: p.y, cat: p.cat))
        }
        if override == nil {
            stops.append(RunStop(kind: .task, id: "cash", name: "Store hold-up, then bank it", sub: "Carried cash is lost if busted",
                                 tag: "MONEY", status: .money))
        }
        guard !stops.isEmpty else { return }
        state.run = RunPlan(title: title ?? "Your \(state.mins) min run", stops: stops, idx: 0)
        runSource = source
        showRun = true
    }

    /// "Done, next" marks the stop; "Skip" just moves on.
    func advanceRun(markDone: Bool) {
        guard var run = state.run, let cur = run.current else { return }
        if markDone {
            if cur.kind == .place { state.found[cur.id] = Date() }
            else if cur.id != "cash" && !cur.repeatable { state.done[cur.id] = Date() }
        }
        run.idx += 1
        state.run = run
    }

    func endRun() { state.run = nil; showRun = false }

    // MARK: live activity

    private func syncLiveActivity() {
        let run = state.run
        Task { await LiveRun.sync(run) }
    }
}

extension String {
    /// Drop the trailing "Stunt Jump" from names so the run line ends stay short.
    var shortStop: String {
        var s = self
        for suffix in [" Stunt Jump", " Stunt"] where s.hasSuffix(suffix) { s.removeLast(suffix.count); break }
        return s
    }
}
