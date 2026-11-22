import SwiftUI

struct GuideView: View {
    enum Section: String, CaseIterable { case collect, missions, money, cheats
        var title: String { rawValue.capitalized }
    }

    @Environment(Store.self) private var store
    @State private var section: Section = Launch.value("-RSGuide").flatMap(Section.init(rawValue:)) ?? .collect

    var body: some View {
        let data = store.data!
        let cc = data.collectibleCats
        let total = cc.reduce(0) { $0 + $1.count }
        let got = cc.reduce(0) { $0 + store.foundCount($1.id) }
        List {
            Group {
                Text("Guide").font(.system(size: 32, weight: .bold)).foregroundStyle(RS.text)
                    .padding(.horizontal, 4).padding(.top, 8)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionLabel("Collectibles found")
                        Spacer()
                        Text("\(got)").font(.mono(26, .bold)).foregroundStyle(RS.text).contentTransition(.numericText(value: Double(got)))
                        Text("/ \(total)").font(.mono(15)).foregroundStyle(RS.text2)
                    }
                    ProgressBar(fraction: total == 0 ? 0 : Double(got) / Double(total))
                }
                .rsCard()
                SegPicker(selection: $section, options: Section.allCases, title: { $0.title })
            }
            .plainRow()

            switch section {
            case .collect: collect(data)
            case .missions: missions(data)
            case .money: money(data)
            case .cheats: cheats(data)
            }

            Text("Unofficial fan guide. Not affiliated with Rockstar Games or Take-Two Interactive.")
                .font(.system(size: 12)).foregroundStyle(RS.text2).plainRow()
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(RS.bg)
        .rsStatusBarScrim()
        .animation(.spring(duration: 0.35), value: section)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .listSectionSpacing(12)
    }

    // MARK: sections

    @ViewBuilder private func collect(_ data: GameData) -> some View {
        SwiftUI.Section {
            ForEach(data.collectibleCats) { c in
                let f = store.foundCount(c.id)
                Button {
                    store.checklistCat = c.id
                    store.tab = .checklist
                } label: {
                    HStack(spacing: 12) {
                        CategoryBadge(cat: c.id, size: 26)
                        Text(c.name).font(.system(size: 16, weight: .medium)).foregroundStyle(RS.text)
                            .frame(width: 118, alignment: .leading).lineLimit(1).minimumScaleFactor(0.85)
                        ProgressBar(fraction: Double(f) / Double(max(1, c.count)), height: 5)
                        HStack(spacing: 0) {
                            Text("\(f)").font(.mono(14, .semibold)).foregroundStyle(RS.text)
                            Text("/\(c.count)").font(.mono(12)).foregroundStyle(RS.text2)
                        }
                        .frame(width: 58, alignment: .trailing)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(RS.text3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(RS.card)
            }
        }
    }

    @ViewBuilder private func missions(_ data: GameData) -> some View {
        let ms = data.guide.missions
        let withCh = ms.filter { $0.ch != nil }.count
        Text("\(ms.count) of 91 story missions listed so far, \(withCh) with a chapter. More as the data fills in.")
            .font(.system(size: 13)).foregroundStyle(RS.text2).plainRow()
        ForEach(groupedMissions(ms), id: \.0) { title, list in
            SwiftUI.Section {
                ForEach(list) { m in CheckRow(id: m.id, name: m.name, sub: m.area ?? "") }
            } header: { SectionLabel(title) }
        }
        SwiftUI.Section {
            ForEach(data.guide.side) { m in CheckRow(id: m.id, name: m.name, sub: m.giver.map { "Given by " + $0 } ?? "") }
        } header: { SectionLabel("Strangers & Freaks") } footer: {
            Text("The trophy needs 8 qualifying questlines. Guides disagree on which ones count.")
        }
    }

    private func groupedMissions(_ ms: [Mission]) -> [(String, [Mission])] {
        var order: [String] = []
        var groups: [String: [Mission]] = [:]
        for m in ms {
            let k = m.ch == nil ? "Chapter not listed yet" : (m.ch == 0 ? "Prologue" : "Chapter \(m.ch!)")
            if groups[k] == nil { order.append(k) }
            groups[k, default: []].append(m)
        }
        func rank(_ k: String) -> (Int, String) {
            if k == "Prologue" { return (0, k) }
            if k.hasPrefix("Chapter n") { return (2, k) }
            return (1, k)
        }
        return order.sorted { rank($0) < rank($1) }.map { ($0, groups[$0]!) }
    }

    @ViewBuilder private func money(_ data: GameData) -> some View {
        SwiftUI.Section {
            ForEach(data.money.rules, id: \.text) { r in
                HStack(alignment: .top) {
                    Text(r.text).font(.system(size: 15)).foregroundStyle(RS.text)
                    Spacer()
                    SourceTag(count: r.sources ?? 0)
                }
                .listRowBackground(RS.card)
            }
        } header: { SectionLabel("Rules of the cash") }
        SwiftUI.Section {
            ForEach(data.money.methods, id: \.name) { m in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(m.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(RS.text)
                        Text([m.when, m.note].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 13)).foregroundStyle(RS.text2)
                        if let cat = m.cat {
                            Button {
                                store.state.mapCats = [cat]
                                store.tab = .map
                            } label: {
                                Label("Show on map", systemImage: "map").font(.system(size: 13, weight: .semibold)).foregroundStyle(RS.accentText)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
                    }
                    Spacer()
                    SourceTag(count: m.sources ?? 0)
                }
                .listRowBackground(RS.card)
            }
        } header: { SectionLabel("Ways to make money") } footer: {
            Text("No payout numbers yet. Nobody has confirmed them, so we don't guess.")
        }
    }

    @ViewBuilder private func cheats(_ data: GameData) -> some View {
        SwiftUI.Section {
            ForEach(data.guide.cheats) { c in
                HStack {
                    Text(c.name).font(.system(size: 16, weight: .medium)).foregroundStyle(RS.text)
                    Spacer()
                    Text(c.unlock ?? "").font(.system(size: 13)).foregroundStyle(RS.text2)
                }
                .listRowBackground(RS.card)
            }
        } header: { SectionLabel("Cheats") }
        SwiftUI.Section {
            ForEach(data.guide.trophies) { t in CheckRow(id: t.id, name: t.name, sub: t.how ?? "") }
        } header: { SectionLabel("Trophies") }
    }
}

/// A row you can tick or swipe to mark done. Used for missions and trophies.
struct CheckRow: View {
    @Environment(Store.self) private var store
    let id: String
    let name: String
    let sub: String

    var body: some View {
        let on = store.isDone(id)
        HStack(spacing: 6) {
            CheckButton(on: on, label: "\(name) done") { toggle() }
                .padding(.leading, -10)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 16, weight: .medium)).foregroundStyle(on ? RS.text3 : RS.text)
                    .strikethrough(on, color: RS.text3)
                if !sub.isEmpty { Text(sub).font(.system(size: 13)).foregroundStyle(RS.text2) }
            }
        }
        .listRowBackground(RS.card)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { toggle() } label: { Label(on ? "Undo" : "Done", systemImage: on ? "arrow.uturn.backward" : "checkmark") }
                .tint(on ? .gray : RS.green)
        }
        .sensoryFeedback(trigger: on) { _, new in new ? .success : .impact(weight: .light) }
    }

    private func toggle() { withAnimation(.spring(duration: 0.3)) { store.toggleDone(id) } }
}

extension View {
    func plainRow() -> some View {
        self.listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowSeparator(.hidden)
    }
}
