import SwiftUI

@main
struct StatGithubApp: App {
    @State private var store = Store()

    init() {
        // Thème clair uniquement.
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
    }

    var body: some Scene {
        WindowGroup("StatGithub") {
            ContentView()
                .environment(store)
                .preferredColorScheme(.light)
                .frame(minWidth: 1020, minHeight: 680)
                .task {
                    if store.connected && !store.isDemo { await store.refresh() }
                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .sidebar) {
                Button("Actualiser les statistiques") {
                    Task { await store.refresh() }
                }
                .keyboardShortcut("r")
            }
        }
    }
}
