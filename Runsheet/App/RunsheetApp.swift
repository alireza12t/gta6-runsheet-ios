import SwiftUI

@main
struct RunsheetApp: App {
    @State private var store = Store(persist: !Launch.ephemeral)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
