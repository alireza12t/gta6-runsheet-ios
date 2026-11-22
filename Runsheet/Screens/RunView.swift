import SwiftUI

struct RunView: View {
    @Environment(Store.self) private var store
    @State private var camera = MapCamera()
    @State private var routeDraw: CGFloat = 0
    @State private var size: CGSize = .zero
    @State private var doneTick = 0
    @State private var skipTick = 0
    @State private var forward = true

    var body: some View {
        let data = store.data!
        let run = store.state.run ?? RunPlan(title: "", stops: [])
        let placeStops = run.stops.enumerated().filter { $0.element.kind == .place }
        let route = placeStops.compactMap { $0.element.point }
        let doneIdx = placeStops.filter { $0.offset < run.idx }.count
        GeometryReader { g in
            MapCanvas(camera: camera, routeDraw: routeDraw, rings: data.rings, regions: data.regions, pins: [],
                      waypoint: nil, route: route, routeDone: doneIdx,
                      routeCurrent: run.isComplete ? nil : (run.current?.kind == .place ? doneIdx : nil))
                .modifier(MapGestures(camera: $camera, onTap: { _ in }))
                .ignoresSafeArea()
                .onAppear {
                    size = g.size
                    fit(route, in: g.size, safeTop: g.safeAreaInsets.top)
                    withAnimation(.easeInOut(duration: 1.4).delay(0.35)) { routeDraw = 1 }
                }
        }
        .overlay(alignment: .top) { topButtons }
        .overlay(alignment: .bottom) {
            Group {
                if run.total == 0 { EmptyView() }   // run just ended, cover is closing
                else if run.isComplete { completeCard(run) } else { card(run) }
            }
            .padding(.horizontal, 10).padding(.bottom, 6)
        }
        .background(RS.sea)
        .sensoryFeedback(.success, trigger: doneTick)
        .sensoryFeedback(.impact(weight: .light), trigger: skipTick)
        .sensoryFeedback(trigger: run.isComplete) { _, new in new && run.total > 0 ? .success : nil }
    }

    private var topButtons: some View {
        HStack {
            GlassIconButton(symbol: "chevron.left", label: "Back to Plan") { store.showRun = false }
            Spacer()
            Menu {
                Button("End this run", systemImage: "xmark.circle", role: .destructive) { store.endRun() }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 17, weight: .semibold)).foregroundStyle(RS.text)
                    .frame(width: 44, height: 44).contentShape(Circle())
            }
            .rsGlass(in: Circle(), interactive: true)
            .accessibilityLabel("Run options")
        }
        .padding(.horizontal, 16).padding(.top, 4)
    }

    private func card(_ run: RunPlan) -> some View {
        let cur = run.current!
        let upcoming = Array(run.stops.dropFirst(run.idx + 1).prefix(4))
        return VStack(alignment: .leading, spacing: 14) {
            Capsule().fill(RS.fill2).frame(width: 36, height: 5).frame(maxWidth: .infinity)
            HStack {
                SectionLabel("\(run.title) · stop \(run.idx + 1) of \(run.total)")
                    .contentTransition(.numericText())
                Spacer()
                StatusTag(label: "IN PROGRESS", status: .live)
            }
            VStack(spacing: 6) {
                RunLine(index: run.idx, total: run.total)
                HStack {
                    Text(run.stops.first?.name.shortStop ?? "")
                    Spacer()
                    Text("\(run.total - run.idx) to go").font(.mono(12, .semibold)).foregroundStyle(RS.text).contentTransition(.numericText())
                    Spacer()
                    Text(run.stops.last?.name.shortStop ?? "")
                }
                .font(.system(size: 12)).foregroundStyle(RS.text2).lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(cur.kind == .place ? "NEXT: \((cur.sub ?? "").uppercased())" : (cur.tag ?? ""))
                    .font(.system(size: 12, weight: .bold)).kerning(0.6).foregroundStyle(RS.accentText)
                Text(cur.name).font(.system(size: 26, weight: .bold)).foregroundStyle(RS.text).lineLimit(2)
                if cur.kind == .task, let sub = cur.sub { Text(sub).font(.system(size: 14)).foregroundStyle(RS.text2) }
            }
            .id(run.idx)
            .transition(.asymmetric(insertion: .push(from: forward ? .trailing : .leading), removal: .push(from: forward ? .trailing : .leading)))
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()

            HStack(spacing: 10) {
                Button("Skip") {
                    forward = true
                    withAnimation(.spring(duration: 0.45, bounce: 0.2)) { store.advanceRun(markDone: false) }
                    skipTick += 1
                }
                .buttonStyle(RSButtonStyle(kind: .secondary))
                Button {
                    forward = true
                    withAnimation(.spring(duration: 0.45, bounce: 0.2)) { store.advanceRun(markDone: true) }
                    doneTick += 1
                } label: { Label("Done, next", systemImage: "checkmark") }
                .buttonStyle(RSButtonStyle(kind: .primary))
            }

            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Coming up").padding(.bottom, 6)
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { i, s in
                        HStack(spacing: 10) {
                            Text("\(run.idx + i + 2)").font(.mono(13)).foregroundStyle(RS.text3).frame(width: 26, alignment: .leading)
                            Text(s.name).font(.system(size: 15)).foregroundStyle(RS.text).lineLimit(1)
                            Spacer()
                            if s.kind == .task, let st = s.status { StatusTag(label: s.tag ?? "", status: st) }
                            else { Text(s.sub ?? "").font(.system(size: 12)).foregroundStyle(RS.text2) }
                        }
                        .frame(height: 34)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .padding(18)
        .rsGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run in progress")
    }

    private func completeCard(_ run: RunPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule().fill(RS.fill2).frame(width: 36, height: 5).frame(maxWidth: .infinity)
            HStack {
                StatusTag(label: "RUN COMPLETE", status: .ready)
                Spacer()
                Image(systemName: "checkmark.seal.fill").font(.system(size: 28)).foregroundStyle(RS.green)
                    .symbolEffect(.bounce, value: run.isComplete)
            }
            Text("Nice. \(run.total) stops done.").font(.system(size: 26, weight: .bold)).foregroundStyle(RS.text)
            RunLine(index: run.total, total: run.total)
            HStack(spacing: 10) {
                Button("See progress") { store.tab = .guide; store.endRun() }.buttonStyle(RSButtonStyle(kind: .secondary))
                Button("Plan another") { store.tab = .plan; store.endRun() }.buttonStyle(RSButtonStyle(kind: .primary))
            }
        }
        .padding(18)
        .rsGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func fit(_ route: [CGPoint], in size: CGSize, safeTop: CGFloat) {
        let area = CGRect(x: 30, y: safeTop + 60, width: size.width - 60, height: max(160, size.height * 0.38 - safeTop))
        guard let first = route.first else {
            camera = MapCamera.fit(CGRect(x: 0.42, y: 0.35, width: 0.46, height: 0.55), in: area)
            return
        }
        var r = CGRect(origin: first, size: .zero)
        for p in route { r = r.union(CGRect(origin: p, size: .zero)) }
        camera = MapCamera.fit(r.insetBy(dx: -0.01, dy: -0.01), in: area, maxScale: 7000)
    }
}
