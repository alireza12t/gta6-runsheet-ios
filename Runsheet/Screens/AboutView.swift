import SwiftUI

struct AboutView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        return v
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Runsheet").font(.system(size: 28, weight: .bold))
                        Text("Unofficial GTA VI companion · version \(version)").font(.mono(13)).foregroundStyle(RS.text2)
                        Text("Plan a session, find what's left on the map, and run it stop by stop.")
                            .font(.system(size: 15)).foregroundStyle(RS.text2).padding(.top, 4)
                    }
                    .padding(.vertical, 6)
                }
                Section("Where the data comes from") {
                    Text("Map locations come from gta6tracker.org, which builds on the GTA Wiki (CC BY-SA). They are marked unverified, and each entry shows how many sources agree.")
                    Link(destination: URL(string: "https://gta6tracker.org")!) { Label("gta6tracker.org", systemImage: "safari") }
                    Text("Plan board items, missions, cheats and money tips are hand-written from guide summaries. No payout numbers are shown, because none are confirmed.")
                    Text("The map is our own schematic outline, not Rockstar's map.")
                }
                Section("Your data") {
                    Label("Everything stays on this iPhone. No account, no server, no tracking.", systemImage: "lock.iphone")
                    Button("Reset my progress", role: .destructive) { confirmReset = true }
                }
                Section("Open source") {
                    Link(destination: URL(string: "https://github.com/alireza12t/gta6-runsheet-ios")!) {
                        Label("github.com/alireza12t/gta6-runsheet-ios", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: URL(string: "https://alireza12t.github.io/gta6-runsheet/")!) { Label("Web version", systemImage: "globe") }
                    Text("App code is MIT licensed. The loading animation is adapted from gta6-countdown by the same author.")
                }
                Section {
                    Text("Not affiliated with Rockstar Games or Take-Two Interactive. Grand Theft Auto and GTA are their trademarks. This is a fan-made guide with no Rockstar art, logos or fonts.")
                        .font(.system(size: 13)).foregroundStyle(RS.text2)
                }
            }
            .font(.system(size: 15))
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Reset all found, done, waypoint and the current run?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset progress", role: .destructive) { store.resetProgress() }
            }
        }
        .tint(RS.accent)
    }
}
