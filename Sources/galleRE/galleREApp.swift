import SwiftUI

extension Notification.Name {
    static let showHelp = Notification.Name("gallere.showHelp")
}

@main
struct galleREApp: App {
    @StateObject private var store = PhotoStore()

    var body: some Scene {
        WindowGroup("galleRE") {
            ContentView()
                .environmentObject(store)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Button("galleRE Tutorial") {
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}
