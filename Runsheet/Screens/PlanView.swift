import SwiftUI

struct PlanView: View {
    @Environment(Store.self) private var store
    @State private var showAbout = Launch.args.contains("-RSAbout")

    var body: some View {
        @Bindable var store = store
        let data = store.data!
        let items = store.boardItems()
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let run = store.state.run, !run.isComplete { resumeCard(run) }

                // story, character, time
                VStack(spacing: 4) {
                    row("Story progress") {
                        HStack(spacing: 0) {
                            stepButton("chevron.left", "Previous chapter") { store.state.chapter = max(1, store.state.chapter - 1) }
                            Text("Chapter \(store.state.chapter)")
                                .font(.system(size: 15, weight: .semibold)).monospacedDigit()
                                .contentTransition(.numericText(value: Double(store.state.chapter)))
                                .frame(minWidth: 88)
                            stepButton("chevron.right", "Next chapter") { store.state.chapter = min(5, store.state.chapter + 1) }
                        }
                        .background(RS.fill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .sensoryFeedback(.selection, trigger: store.state.chapter)
                    }
                    row("Playing as") {
                        SegPicker(selection: $store.state.who, options: ["Jason", "Lucia"], title: { $0 }).frame(width: 180)
                    }
                    row("In-game time") {
                        SegPicker(selection: $store.state.time, options: ["day", "night"], title: { $0.capitalized }).frame(width: 180)
                    }
                }
                .rsCard(padding: 12)

                // session length + collect tonight
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("How long can you play?")
                    SegPicker(selection: $store.state.mins, options: [20, 40, 60, 90], title: { "\($0)" }, subtitle: { _ in "min" })
                    SectionLabel("Collect tonight").padding(.top, 4)
                    FlowLayout(spacing: 8) {
                        ForEach(data.collectibleCats) { c in
                            Chip(title: c.name, color: RS.color(c.id), count: "\(c.count - store.foundCount(c.id))",
                                 on: store.state.routeCat == c.id) {
                                withAnimation(.spring(duration: 0.35)) { store.state.routeCat = c.id }
                            }
                        }
                    }
                    .sensoryFeedback(.selection, trigger: store.state.routeCat)
                }
                .rsCard()

                // live board
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        SectionLabel("Live board")
                        Spacer()
                        Text("ch \(store.state.chapter) · \(store.state.who) · \(store.state.time)")
                            .font(.mono(12)).foregroundStyle(RS.text2)
                    }
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
                    ForEach(items) { t in
                        BoardRow(item: t)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .opacity.combined(with: .scale(scale: 0.96))))
                        if t.id != items.last?.id { Divider().padding(.leading, 16) }
                    }
                }
                .padding(.bottom, 4)
                .background(RS.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .id("board")
                .animation(.spring(duration: 0.45, bounce: 0.2), value: items.map(\.id))

                Button {
                    store.buildRun(source: "plan")
                } label: {
                    Label("Build my \(store.state.mins) min run", systemImage: "flag.checkered")
                        .contentTransition(.numericText())
                }
                .buttonStyle(RSButtonStyle(kind: .primary))
                .runTransitionSource("plan")
                .sensoryFeedback(.impact(weight: .medium), trigger: store.showRun) { _, new in new }

                Text("Run size is a first guess (stops, not minutes) until we time real drives. Board entries come from guides; \"src\" shows how many agree. Not affiliated with Rockstar Games or Take-Two.")
                    .font(.system(size: 12)).foregroundStyle(RS.text3)
                    .padding(.horizontal, 4).padding(.bottom, 20)
            }
            .padding(.horizontal, 16)
        }
        .onAppear { if Launch.args.contains("-RSScrollBoard") { proxy.scrollTo("board", anchor: .top) } }
        }
        .background(RS.bg)
        .rsStatusBarScrim()
        .sheet(isPresented: $showAbout) { AboutView() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("RUNSHEET · UNOFFICIAL GTA VI GUIDE").font(.system(size: 11, weight: .semibold)).kerning(0.6).foregroundStyle(RS.text2)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                GlassIconButton(symbol: store.state.theme.symbol, label: "Theme: \(store.state.theme.rawValue). Tap to change", size: 38) {
                    withAnimation { store.state.theme = store.state.theme.next }
                }
                .contentTransition(.symbolEffect(.replace))
                GlassIconButton(symbol: "info", label: "About Runsheet", size: 38) { showAbout = true }
            }
            Text("Plan your session").font(.system(size: 32, weight: .bold)).foregroundStyle(RS.text)
        }
        .padding(.horizontal, 4).padding(.top, 8)
    }

    private func resumeCard(_ run: RunPlan) -> some View {
        Button {
            store.runSource = "resume"
            store.showRun = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StatusTag(label: "IN PROGRESS", status: .live)
                    Text(run.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(RS.text).lineLimit(1)
                    Spacer()
                    Text("Resume").font(.system(size: 15, weight: .semibold)).foregroundStyle(RS.accentText)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(RS.accentText)
                }
                RunLine(index: run.idx, total: run.total)
                if let cur = run.current {
                    Text("Next: \(cur.name)").font(.system(size: 14)).foregroundStyle(RS.text2).lineLimit(1)
                }
            }
            .rsCard()
        }
        .buttonStyle(.plain)
        .runTransitionSource("resume")
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func row<C: View>(_ label: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack {
            Text(label).font(.system(size: 16)).foregroundStyle(RS.text)
            Spacer()
            control()
        }
        .frame(minHeight: 48)
        .padding(.horizontal, 4)
    }

    private func stepButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.spring(duration: 0.3)) { action() } } label: {
            Image(systemName: symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(RS.text)
                .frame(width: 40, height: 38).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// One departure-board line: tag, name and note, source count.
struct BoardRow: View {
    let item: BoardItem
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            StatusTag(label: item.label, status: item.status).frame(width: 82, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(RS.text).lineLimit(1)
                if !item.sub.isEmpty { Text(item.sub).font(.system(size: 13)).foregroundStyle(RS.text2).lineLimit(2) }
            }
            Spacer(minLength: 4)
            Text("\(item.sources) src").font(.mono(12)).foregroundStyle(RS.text2)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }
}
