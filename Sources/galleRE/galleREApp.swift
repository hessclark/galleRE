import SwiftUI

extension Notification.Name {
    static let showHelp = Notification.Name("gallere.showHelp")
    static let showAbout = Notification.Name("gallere.showAbout")
}

@main
struct galleREApp: App {
    @StateObject private var store = PhotoStore()
    @StateObject private var clients = ClientsStore()

    var body: some Scene {
        WindowGroup("galleRE") {
            ContentView()
                .environmentObject(store)
                .environmentObject(clients)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About galleRE") {
                    NotificationCenter.default.post(name: .showAbout, object: nil)
                }
                Button("Check for Updates…") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/hessclark/galleRE/releases/latest")!)
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
