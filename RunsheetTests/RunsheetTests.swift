import CoreGraphics
import Foundation
import Testing
@testable import Runsheet

@MainActor
struct DataTests {
    @Test func bundledDataDecodes() throws {
        let d = try GameData.loadBundled()
        #expect(d.places.count == 574)
        #expect(!d.rings.isEmpty)
        #expect(!d.tonight.items.isEmpty)
        // every category count matches the places in it
        for c in d.cats { #expect(d.places(in: c.id).count == c.count, "\(c.id)") }
    }

    @Test func boardRulesMatchWebApp() throws {
        let s = Store(persist: false)
        s.state.chapter = 1; s.state.who = "Lucia"; s.state.time = "night"
        let items = s.boardItems()
        // closing first, cash last
        #expect(items.first?.status == .closing)
        #expect(items.last?.id == "cash")
        #expect(items.contains { $0.id == "mangrove" && $0.label == "LIVE NOW" })
        s.state.who = "Jason"
        #expect(!s.boardItems().contains { $0.id == "mangrove" })
    }

    @Test func runSizeAndDoneRules() throws {
        let s = Store(persist: false)
        s.state.mins = 20; s.state.chapter = 2
        s.buildRun()
        let run = try #require(s.state.run)
        #expect(run.stops.filter { $0.kind == .place }.count == 5)
        #expect(run.stops.last?.id == "cash")
        // a repeatable money task never gets marked done
        while let cur = s.state.run?.current { s.advanceRun(markDone: true); if cur.id == "cash" { break } }
        #expect(s.state.done["cash"] == nil)
        #expect(s.state.found.count == 5)
    }

    @Test func tourVisitsEveryPointOnce() {
        var pts: [CGPoint] = []
        for i in 0..<30 {
            let x = Double((i * 37) % 100) / 100
            let y = Double((i * 61) % 100) / 100
            pts.append(CGPoint(x: x, y: y))
        }
        let t = Route.tour(pts, start: .zero, point: { $0 })
        #expect(t.count == pts.count)
        #expect(Set(t.map { "\($0)" }).count == pts.count)
    }

    @Test func progressSurvivesRelaunch() throws {
        let f = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let a = Store(persist: true, fileURL: f)
        let id = try #require(a.data?.places.first?.id)
        a.toggleFound(id)
        a.state.waypoint = id
        a.state.chapter = 3
        a.buildRun()
        a.advanceRun(markDone: false)
        let b = Store(persist: true, fileURL: f)
        #expect(b.isFound(id))
        #expect(b.state.waypoint == id)
        #expect(b.state.chapter == 3)
        #expect(b.state.run == a.state.run)
        #expect(b.state.run?.idx == 1)
    }

    @Test func unreadableStateIsMovedAside() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = dir.appendingPathComponent("state.json")
        try Data("not json".utf8).write(to: f)
        let s = Store(persist: true, fileURL: f)
        #expect(s.state == AppState())
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.contains { $0.hasPrefix("state-unreadable-") })
    }
}
