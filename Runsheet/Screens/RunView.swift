import SwiftUI

struct RunView: View {
    @Environment(Store.self) private var store
    @State private var camera = MapCamera()
    @State private var routeDraw: CGFloat = 0
    @State private var size: CGSize = .zero
    @State private var doneTick = 0
    @State private var skipTick = 0
    @State private var forward = true
    @State private var showUpcoming = false

    var body: some View {
        let data = store.data!
        let run = store.state.run ?? RunPlan(title: "", stops: [])
        let placeStops = run.stops.enumerated().filter { $0.element.kind == .place }
        let route = placeStops.compactMap { $0.element.point }
        let doneIdx = placeStops.filter { $0.offset < run.idx }.count
        GeometryReader { g in
            MapCanvas(camera: camera, routeDraw: routeDraw, data: data,
                      route: route, routeDone: doneIdx,
                      routeCurrent: run.isComplete ? nil : (run.current?.kind == .place ? doneIdx : nil),
                      tileVersion: TileStore.shared.version)
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
        .background(Color(UIColor(hex: 0x2F90AF)))
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
        return VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(RS.fill2).frame(width: 36, height: 5).frame(maxWidth: .infinity)
            HStack {
                SectionLabel("Stop \(run.idx + 1) of \(run.total)")
                    .contentTransition(.numericText())
                    .lineLimit(1)
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
                Text(cur.name).font(.system(size: 24, weight: .bold)).foregroundStyle(RS.text).lineLimit(2)
                    .frame(height: 62, alignment: .topLeading)
                Text(cur.kind == .task ? (cur.sub ?? "") : " ").font(.system(size: 14)).foregroundStyle(RS.text2).lineLimit(1)
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

            if !upcoming.isEmpty && !showUpcoming {
                Button { withAnimation(.spring(duration: 0.4)) { showUpcoming = true } } label: {
                    HStack(spacing: 4) {
                        Text("Coming up (\(run.total - run.idx - 1))")
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(RS.accentText)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            if !upcoming.isEmpty && showUpcoming {
                VStack(alignment: .leading, spacing: 0) {
                    Button { withAnimation(.spring(duration: 0.4)) { showUpcoming = false } } label: {
                        HStack(spacing: 4) { SectionLabel("Coming up"); Image(systemName: "chevron.up").font(.system(size: 10, weight: .bold)).foregroundStyle(RS.text2) }
                            .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
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
            Text(run.skipped ?? 0 > 0 ? "\(run.done) done, \(run.skipped ?? 0) skipped" : "Nice. \(run.done) stops done.")
                .font(.system(size: 26, weight: .bold)).foregroundStyle(RS.text)
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
        // fit the route in the space above the card
        let area = CGRect(x: 36, y: safeTop + 64, width: size.width - 72, height: max(160, size.height * 0.40 - safeTop - 30))
        guard let first = route.first else {
            camera = MapCamera.fit(CGRect(x: 0.42, y: 0.35, width: 0.46, height: 0.55), in: area)
            return
        }
        var r = CGRect(origin: first, size: .zero)
        for p in route { r = r.union(CGRect(origin: p, size: .zero)) }
        camera = MapCamera.fit(r.insetBy(dx: -0.01, dy: -0.01), in: area, maxScale: 7000)
    }
}
