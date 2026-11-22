import SwiftUI

struct RootView: View {
    @Environment(Store.self) private var store
    @Namespace private var runNS
    @State private var showLoading = true

    var body: some View {
        @Bindable var store = store
        ZStack {
            if let data = store.data {
                TabView(selection: $store.tab) {
                    Tab("Plan", systemImage: "list.bullet.rectangle.portrait", value: AppTab.plan) { PlanView() }
                    Tab("Map", systemImage: "map", value: AppTab.map) { MapScreen() }
                    Tab("Guide", systemImage: "book.closed", value: AppTab.guide) { GuideView() }
                    Tab("Checklist", systemImage: "checklist", value: AppTab.checklist) { ChecklistView() }
                }
                .tint(RS.accent)
                .rsMinimizeTabBar()
                .environment(\.runNamespace, runNS)
                .fullScreenCover(isPresented: $store.showRun) {
                    RunView()
                        .navigationTransition(.zoom(sourceID: store.runSource, in: runNS))
                }
                .overlay(alignment: .top) {
                    if let t = store.toast {
                        ToastView(text: t)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
                .animation(.spring(duration: 0.4), value: store.toast)

                if showLoading {
                    LoadingView(rings: data.rings, ready: true, hold: Launch.holdLoading) {
                        withAnimation(.easeOut(duration: 0.45)) { showLoading = false }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 1.08)))
                    .zIndex(1)
                }
            } else {
                ContentUnavailableView("Couldn't load data", systemImage: "exclamationmark.triangle",
                                       description: Text(store.loadError ?? ""))
            }
        }
        .preferredColorScheme(store.state.theme == .auto ? nil : (store.state.theme == .dark ? .dark : .light))
        .onAppear(perform: applyLaunchArgs)
    }

    /// Launch arguments for screenshots and UI checks (`-RSTab map`, `-RSSkipLoading`, ...).
    private func applyLaunchArgs() {
        if Launch.skipLoading { showLoading = false }
        if let t = Launch.tab { store.tab = t }
        if let c = Launch.checklistCat { store.checklistCat = c }
        if let p = Launch.place { store.mapFocus = p }
        // screenshot state: tick every third place and a few missions (use with -RSEphemeral)
        if Launch.args.contains("-RSDemoFound"), let d = store.data {
            for (i, p) in d.places.enumerated() where i % 3 == 0 { store.state.found[p.id] = Date() }
            for m in d.guide.missions.prefix(6) { store.state.done[m.id] = Date() }
        }
        if Launch.demoRun {
            store.buildRun(source: "plan")
            for _ in 0..<Launch.runSteps { store.advanceRun(markDone: true) }
        }
    }
}

enum Launch {
    static let args = ProcessInfo.processInfo.arguments
    static func value(_ key: String) -> String? {
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    static var skipLoading: Bool { args.contains("-RSSkipLoading") }
    static var tab: AppTab? { value("-RSTab").flatMap(AppTab.init(rawValue:)) }
    static var checklistCat: String? { value("-RSChecklist") }
    static var place: String? { value("-RSPlace") }
    static var demoRun: Bool { args.contains("-RSDemoRun") }
    static var runSteps: Int { value("-RSRunSteps").flatMap(Int.init) ?? 0 }
    static var holdLoading: Double? { value("-RSHoldLoading").flatMap(Double.init) }
    static var ephemeral: Bool { args.contains("-RSEphemeral") }
}

// MARK: shared namespace for the zoom transition into the Run screen

extension EnvironmentValues {
    @Entry var runNamespace: Namespace.ID? = nil
}

extension View {
    /// Mark a view as the place the Run screen zooms out of.
    @ViewBuilder
    func runTransitionSource(_ id: String) -> some View {
        modifier(RunSource(id: id))
    }
}

private struct RunSource: ViewModifier {
    let id: String
    @Environment(\.runNamespace) private var ns
    func body(content: Content) -> some View {
        if let ns { content.matchedTransitionSource(id: id, in: ns) } else { content }
    }
}
