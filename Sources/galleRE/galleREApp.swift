import SwiftUI

extension Notification.Name {
    static let showHelp = Notification.Name("gallere.showHelp")
    static let showAbout = Notification.Name("gallere.showAbout")
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
            CommandGroup(replacing: .appInfo) {
                Button("About galleRE") {
                    NotificationCenter.default.post(name: .showAbout, object: nil)
                }
            }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Button("galleRE Tutorial") {
                    NotificationCenter.default.post(name: .showHelp, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
                Divider()
                Button("Report a Bug…") { Support.reportBug() }
                Button("View Source on GitHub") { NSWorkspace.shared.open(Support.githubURL) }
                Button("Donate (Venmo)") { NSWorkspace.shared.open(Support.venmoURL) }
            }
        }
    }
}
