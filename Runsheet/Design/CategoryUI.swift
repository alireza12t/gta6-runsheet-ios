import SwiftUI

/// One icon per category. SF Symbols standing in for the web app's hand-drawn line icons.
enum CatIcon {
    static let symbols: [String: String] = [
        "stunt-jumps": "bolt.fill", "nine1nine": "phone.fill", "curiosity": "eye.fill", "jack-of-hearts": "heart.fill",
        "magazine": "book.fill", "sculpture": "diamond.fill", "delights": "sparkle", "under-the-bridge": "airplane",
        "book-swap": "book.fill", "1010-mural": "paintbrush.fill", "unique-playlist": "music.note", "animal-crackers": "pawprint.fill",
        "arcade-machine": "gamecontroller.fill", "safe": "lock.fill", "atm-towable": "dollarsign", "bank": "dollarsign",
        "big-bank": "dollarsign", "payday-loans": "dollarsign", "mission": "star.fill", "side": "questionmark", "contact": "person.fill",
        "safehouse": "house.fill", "ammu-nation": "scope", "pay-n-spray": "drop.fill", "purchasable-garage": "door.garage.closed",
        "garage": "door.garage.closed", "shop": "bag.fill", "fast-food": "fork.knife", "street-food": "fork.knife",
        "gas-station": "fuelpump.fill", "atm": "dollarsign", "landmark": "camera.fill", "transport": "tram.fill", "vehicle": "car.fill",
        "animal": "pawprint.fill", "building": "building.2.fill", "structure": "building.2.fill",
    ]
    static func name(_ cat: String) -> String { symbols[cat] ?? "star.fill" }
}

/// Coloured round badge with the category icon.
struct CategoryBadge: View {
    let cat: String
    var size: CGFloat = 28
    var body: some View {
        Image(systemName: CatIcon.name(cat))
            .font(.system(size: size * 0.48, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RS.color(cat), in: Circle())
            .accessibilityHidden(true)
    }
}

let groupNames: [String: String] = [
    "collectible": "Collectibles", "money": "Money", "story": "Story", "services": "Services", "shops": "Shops & food", "places": "Places",
]
let groupOrder = ["collectible", "money", "story", "services", "shops", "places"]

/// One button showing the chosen category; opens a grouped list (replaces the long chip rows).
struct CategoryPickerButton: View {
    let cat: String
    let name: String
    let meta: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CategoryBadge(cat: cat, size: 30)
                Text(name).font(.system(size: 16, weight: .semibold)).foregroundStyle(RS.text)
                Spacer()
                Text(meta).font(.mono(13)).foregroundStyle(RS.text2)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(RS.text3)
            }
            .padding(.horizontal, 12).frame(minHeight: 52)
            .background(RS.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the category list")
    }
}

struct CategoryPickerSheet: View {
    let title: String
    let cats: [Category]
    let selected: String
    let meta: (Category) -> String
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let groups = groupOrder.filter { g in cats.contains { $0.group == g } }
                ForEach(groups, id: \.self) { g in
                    Section(groups.count > 1 ? (groupNames[g] ?? g) : "") {
                        ForEach(cats.filter { $0.group == g }) { c in
                            Button {
                                onPick(c.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    CategoryBadge(cat: c.id)
                                    Text(c.name).foregroundStyle(RS.text)
                                    Spacer()
                                    Text(meta(c)).font(.mono(13)).foregroundStyle(RS.text2)
                                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(RS.accent).opacity(c.id == selected ? 1 : 0)
                                }
                                .frame(minHeight: 40)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(c.id == selected ? .isSelected : [])
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(RS.accent)
        .presentationDetents([.medium, .large])
    }
}

/// The map's Filters panel: categories in groups with switches, Show all / Hide all per group, Clear all, Hide found.
struct FiltersSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    static let notTracked: Set<String> = ["building", "structure"]

    var body: some View {
        @Bindable var store = store
        let data = store.data!
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $store.state.hideFound) { Label("Hide found", systemImage: "eye.slash") }
                }
                ForEach(groupOrder, id: \.self) { g in
                    let cs = data.cats.filter { $0.group == g }
                    if !cs.isEmpty {
                        let all = cs.allSatisfy { store.state.mapCats.contains($0.id) }
                        Section {
                            ForEach(cs) { c in
                                Toggle(isOn: binding(c.id)) {
                                    HStack(spacing: 12) {
                                        CategoryBadge(cat: c.id)
                                        Text(c.name)
                                        Spacer()
                                        Text(Self.notTracked.contains(c.id) ? "\(c.count)" : "\(store.foundCount(c.id))/\(c.count)")
                                            .font(.mono(12)).foregroundStyle(RS.text2)
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text(groupNames[g] ?? g)
                                Spacer()
                                Button(all ? "Hide all" : "Show all") {
                                    let ids = cs.map(\.id)
                                    if all { store.state.mapCats.removeAll { ids.contains($0) } }
                                    else { for id in ids where !store.state.mapCats.contains(id) { store.state.mapCats.append(id) } }
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .textCase(nil)
                            }
                        }
                    }
                }
                Section {
                    Text("Buildings and structures show from a closer zoom, and only for the part of the map you're looking at.")
                        .font(.system(size: 12)).foregroundStyle(RS.text2)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Clear all") { store.state.mapCats = [] } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(RS.accent)
        .sensoryFeedback(.selection, trigger: store.state.mapCats)
    }

    private func binding(_ id: String) -> Binding<Bool> {
        Binding(get: { store.state.mapCats.contains(id) },
                set: { on in
                    if on { if !store.state.mapCats.contains(id) { store.state.mapCats.append(id) } }
                    else { store.state.mapCats.removeAll { $0 == id } }
                })
    }
}
