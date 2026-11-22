import SwiftUI

struct ChecklistView: View {
    @Environment(Store.self) private var store
    @State private var foundTick = 0
    @State private var order: [String] = []     // sort frozen while you tick, so rows stay under your finger
    @State private var orderCat = ""
    @State private var showPicker = false

    var body: some View {
        let data = store.data!
        let cats = data.checklistCats
        let cat = cats.first { $0.id == store.checklistCat }?.id ?? cats.first!.id
        let items = orderCat == cat ? order.compactMap { data.placeByID[$0] } : sorted(data, cat)
        let f = store.foundCount(cat), n = items.count

        List {
            Group {
                Text("Checklist").font(.system(size: 32, weight: .bold)).foregroundStyle(RS.text)
                    .padding(.horizontal, 4).padding(.top, 8)
                CategoryPickerButton(cat: cat, name: data.catName(cat), meta: "\(f)/\(n) found") { showPicker = true }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionLabel(data.catName(cat))
                        Spacer()
                        Text("\(f)").font(.mono(26, .bold)).foregroundStyle(RS.text).contentTransition(.numericText(value: Double(f)))
                        Text("/ \(n)").font(.mono(15)).foregroundStyle(RS.text2)
                    }
                    ProgressBar(fraction: n == 0 ? 0 : Double(f) / Double(n))
                    Button(f == n ? "All found" : "Route the \(n - f) left") {
                        let left = items.filter { !store.isFound($0.id) }
                        store.buildRun(places: left, title: "\(data.catName(cat)), \(n - f) left", source: "checklist")
                    }
                    .buttonStyle(RSButtonStyle(kind: .secondary))
                    .disabled(f == n)
                    .runTransitionSource("checklist")
                }
                .rsCard()
                Text("Swipe right to mark found, left to see it on the map.")
                    .font(.system(size: 12)).foregroundStyle(RS.text2).padding(.horizontal, 4)
            }
            .plainRow()

            SwiftUI.Section {
                ForEach(items) { p in
                    let on = store.isFound(p.id)
                    HStack(spacing: 6) {
                        CheckButton(on: on, label: "\(p.name) found") { toggle(p) }
                            .padding(.leading, -10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(.system(size: 16, weight: .medium)).foregroundStyle(on ? RS.text3 : RS.text)
                                .strikethrough(on, color: RS.text3)
                            if let a = p.area, !a.isEmpty { Text(a).font(.system(size: 13)).foregroundStyle(RS.text2) }
                        }
                        Spacer()
                        Button("Map") { showOnMap(p) }
                            .font(.system(size: 14, weight: .semibold))
                            .frame(minWidth: 44, minHeight: 44)
                            .foregroundStyle(RS.accentText)
                            .buttonStyle(.borderless)
                    }
                    .listRowBackground(RS.card)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { toggle(p) } label: { Label(on ? "Not found" : "Found", systemImage: on ? "arrow.uturn.backward" : "checkmark") }
                            .tint(on ? .gray : RS.green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button { showOnMap(p) } label: { Label("Map", systemImage: "map") }.tint(RS.accent)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(RS.bg)
        .rsStatusBarScrim()
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .sensoryFeedback(trigger: foundTick) { _, _ in .success }
        .sheet(isPresented: $showPicker) {
            CategoryPickerSheet(title: "Checklist", cats: cats, selected: cat,
                                meta: { "\(store.foundCount($0.id))/\($0.count) found" }) { id in
                withAnimation(.spring(duration: 0.35)) { store.checklistCat = id }
            }
        }
        .onAppear { freeze(data, cat) }
        .onChange(of: cat) { _, c in freeze(data, c) }
    }

    /// Unfound first, then by name. Only re-sorted when the list opens or the category changes.
    private func sorted(_ data: GameData, _ cat: String) -> [Place] {
        data.places(in: cat).sorted {
            let a = store.isFound($0.id), b = store.isFound($1.id)
            return a != b ? !a : $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    private func freeze(_ data: GameData, _ cat: String) {
        order = sorted(data, cat).map(\.id)
        orderCat = cat
    }

    private func toggle(_ p: Place) {
        var nowFound = false
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) { nowFound = store.toggleFound(p.id) }
        if nowFound {
            foundTick += 1
            let n = store.data?.places(in: p.cat).count ?? 0
            store.flash("Found! \(store.foundCount(p.cat))/\(n)")
        }
    }

    private func showOnMap(_ p: Place) {
        store.mapFocus = p.id
        store.tab = .map
    }
}
