import SwiftUI

struct MapScreen: View {
    @Environment(Store.self) private var store
    @State private var camera = MapCamera()
    @State private var size: CGSize = .zero
    @State private var didFit = false
    @State private var selected: Place?
    @State private var query = ""
    @FocusState private var searching: Bool
    @State private var visibleCount = 0

    var body: some View {
        let data = store.data!
        let shown = shownPlaces(data)
        GeometryReader { g in
            ZStack {
                MapCanvas(camera: camera, routeDraw: 1, rings: data.rings, regions: data.regions,
                          pins: shown.map { MapPin(id: $0.id, point: $0.point, color: RS.color($0.cat), found: store.isFound($0.id)) },
                          waypoint: store.state.waypoint.flatMap { data.placeByID[$0]?.point },
                          selected: selected?.id)
                    .modifier(MapGestures(camera: $camera, onTap: { tap($0, shown: shown) }, onMoveEnd: updateVisible))
                    .ignoresSafeArea()
            }
            .onAppear { size = g.size; fitIfNeeded(); focusIfNeeded() }
            .onChange(of: g.size) { _, s in size = s; fitIfNeeded() }
        }
        .overlay(alignment: .top) { topBar(data) }
        .overlay(alignment: .trailing) { controls(data) }
        .overlay(alignment: .bottom) { routeButton }
        .rsSolidTabBarBeforeGlass()
        .onChange(of: store.mapFocus) { _, _ in focusIfNeeded() }
        .onChange(of: store.state.mapCats) { _, _ in updateVisible() }
        .onChange(of: store.state.hideFound) { _, _ in updateVisible() }
        .onChange(of: store.state.found) { _, _ in updateVisible() }
        .sheet(item: $selected) { p in
            PlaceSheet(place: p)
                .presentationDetents([.height(300), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(300)))
        }
    }

    // MARK: pieces

    private func topBar(_ data: GameData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(RS.text2)
                TextField("Search \(data.places.count) places", text: $query)
                    .focused($searching)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(RS.text3) }
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14).frame(height: 46)
            .rsGlass(in: RoundedRectangle(cornerRadius: 23, style: .continuous))
            .padding(.horizontal, 16)

            if query.trimmingCharacters(in: .whitespaces).count >= 2 {
                results(data)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                chips(data)
            }
        }
        .padding(.top, 6)
        .animation(.spring(duration: 0.35), value: query.count >= 2)
    }

    private func chips(_ data: GameData) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "Hide found", on: store.state.hideFound, glass: true) {
                    withAnimation { store.state.hideFound.toggle() }
                }
                ForEach(data.cats) { c in
                    Chip(title: c.name, color: RS.color(c.id), count: "\(c.count)", on: store.state.mapCats.contains(c.id), glass: true) {
                        if let i = store.state.mapCats.firstIndex(of: c.id) { store.state.mapCats.remove(at: i) }
                        else { store.state.mapCats.append(c.id) }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 2)
        }
        .sensoryFeedback(.selection, trigger: store.state.mapCats)
    }

    private func results(_ data: GameData) -> some View {
        let s = query.trimmingCharacters(in: .whitespaces).lowercased()
        let hits = data.places.filter { $0.name.lowercased().contains(s) }.prefix(12)
        return VStack(spacing: 0) {
            if hits.isEmpty {
                Text("No matches").foregroundStyle(RS.text2).frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }
            ForEach(Array(hits)) { p in
                Button {
                    open(p, zoom: true)
                    query = ""; searching = false
                } label: {
                    HStack {
                        Circle().fill(RS.color(p.cat)).frame(width: 9, height: 9)
                        Text(p.name).foregroundStyle(RS.text).lineLimit(1)
                        Spacer()
                        Text(data.catName(p.cat)).font(.system(size: 13)).foregroundStyle(RS.text2)
                    }
                    .padding(.horizontal, 14).frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if p.id != hits.last?.id { Divider().padding(.leading, 14) }
            }
        }
        .rsGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func controls(_ data: GameData) -> some View {
        GlassGroup(spacing: 10) {
            VStack(spacing: 10) {
                GlassIconButton(symbol: "plus", label: "Zoom in") { zoom(1.6) }
                GlassIconButton(symbol: "minus", label: "Zoom out") { zoom(1 / 1.6) }
                GlassIconButton(symbol: "location.north.line.fill", label: "Go to waypoint", tint: RS.accent) {
                    guard let w = store.state.waypoint, let p = data.placeByID[w] else {
                        store.flash("No waypoint yet. Tap a pin to set one."); return
                    }
                    open(p, zoom: true)
                }
            }
        }
        .padding(.trailing, 16)
        .offset(y: 30)
    }

    private var routeButton: some View {
        Button {
            routeOnScreen()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                Text("Route what's on screen")
                if visibleCount > 0 {
                    Text("\(visibleCount) stops").font(.mono(14, .bold)).foregroundStyle(RS.accentText)
                        .contentTransition(.numericText())
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(RS.text)
            .padding(.horizontal, 18).frame(height: 48)
            .rsGlass(in: Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
        .disabled(visibleCount == 0)
        .opacity(visibleCount == 0 ? 0.6 : 1)
        .runTransitionSource("map")
        .padding(.bottom, 12)
        .animation(.spring, value: visibleCount)
    }

    // MARK: logic

    private func shownPlaces(_ data: GameData) -> [Place] {
        let cats = Set(store.state.mapCats)
        return data.places.filter { cats.contains($0.cat) && !(store.state.hideFound && store.isFound($0.id)) }
    }

    private func fitIfNeeded() {
        guard !didFit, size.width > 0 else { return }
        didFit = true
        camera = MapCamera.fit(CGRect(x: 0.42, y: 0.35, width: 0.46, height: 0.55),
                               in: CGRect(origin: .zero, size: size).insetBy(dx: 10, dy: 60))
        updateVisible()
    }

    private func focusIfNeeded() {
        guard let id = store.mapFocus, let p = store.data?.placeByID[id], size.width > 0 else { return }
        store.mapFocus = nil
        if !store.state.mapCats.contains(p.cat) { store.state.mapCats.append(p.cat) }
        open(p, zoom: true)
    }

    private func open(_ p: Place, zoom: Bool) {
        if !store.state.mapCats.contains(p.cat) { store.state.mapCats.append(p.cat) }
        if zoom {
            withAnimation(.spring(duration: 0.7, bounce: 0.1)) {
                camera = camera.centered(on: p.point, in: size, scale: max(camera.scale, 3200), yBias: 0.32)
            }
        }
        selected = p
        updateVisible()
    }

    private func zoom(_ k: CGFloat) {
        withAnimation(.spring(duration: 0.4, bounce: 0.1)) {
            camera = camera.zoomed(by: k, around: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        updateVisible()
    }

    private func tap(_ loc: CGPoint, shown: [Place]) {
        searching = false
        var best: Place?
        var bestD: CGFloat = 26
        for p in shown {
            let s = camera.toScreen(p.point)
            let d = hypot(s.x - loc.x, s.y - loc.y)
            if d < bestD { bestD = d; best = p }
        }
        if let best { open(best, zoom: false) } else { selected = nil }
    }

    private func visiblePlaces() -> [Place] {
        guard let data = store.data, size.width > 0 else { return [] }
        let a = camera.toMap(.zero), b = camera.toMap(CGPoint(x: size.width, y: size.height))
        let r = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
        return shownPlaces(data).filter { !store.isFound($0.id) && r.contains($0.point) }
    }

    private func updateVisible() {
        // wait a beat so momentum settles
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            visibleCount = visiblePlaces().count
        }
    }

    private func routeOnScreen() {
        let pts = visiblePlaces()
        guard !pts.isEmpty else { return }
        let c = camera.toMap(CGPoint(x: size.width / 2, y: size.height / 2))
        let near = Array(pts.sorted { Route.dist($0.point, c) < Route.dist($1.point, c) }.prefix(60))
        selected = nil
        store.buildRun(places: near, title: "\(near.count) stops on screen", from: c, source: "map")
    }
}

struct PlaceSheet: View {
    @Environment(Store.self) private var store
    let place: Place
    @State private var foundTick = 0

    var body: some View {
        let data = store.data!
        let found = store.isFound(place.id)
        let isWp = store.state.waypoint == place.id
        let cat = place.cat
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(RS.color(cat)).frame(width: 9, height: 9)
                    SectionLabel(data.catName(cat) + (place.ch.map { " · Chapter \($0)" } ?? ""), color: RS.accentText)
                }
                Text(place.name).font(.system(size: 24, weight: .bold)).foregroundStyle(RS.text)
                if let area = place.area, !area.isEmpty { Text(area).font(.system(size: 15)).foregroundStyle(RS.text2) }
            }
            HStack(spacing: 8) {
                SourceTag(count: place.sources ?? 0)
                Text(place.source ?? "").font(.system(size: 12)).foregroundStyle(RS.text2)
            }
            if found {
                Label("Found. \(store.foundCount(cat)) of \(data.places(in: cat).count) \(data.catName(cat).lowercased())", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RS.green)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            HStack(spacing: 10) {
                Button(isWp ? "Clear waypoint" : "Set waypoint") {
                    store.state.waypoint = isWp ? nil : place.id
                    store.flash(isWp ? "Waypoint cleared" : "Waypoint set")
                }
                .buttonStyle(RSButtonStyle(kind: .secondary))
                Button {
                    withAnimation(.spring(duration: 0.4, bounce: 0.4)) { _ = store.toggleFound(place.id) }
                    foundTick += 1
                } label: {
                    Label(found ? "Not found" : "Mark found", systemImage: found ? "arrow.uturn.backward" : "checkmark")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(RSButtonStyle(kind: .primary))
            }
        }
        .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 10)
        .frame(maxHeight: .infinity, alignment: .top)
        .sensoryFeedback(trigger: foundTick) { _, _ in store.isFound(place.id) ? .success : .impact(weight: .light) }
        .sensoryFeedback(.selection, trigger: store.state.waypoint)
    }
}
