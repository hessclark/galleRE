import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let githubURL = URL(string: "https://github.com/hessclark/galleRE")!
    private let venmoURL  = URL(string: "https://venmo.com/u/ClarkHess")!

    var body: some View {
        VStack(spacing: 18) {
            if let icon = NSImage(named: "AppIcon") ?? loadBundledIcon() {
                Image(nsImage: icon)
                    .resizable().frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                Image(systemName: "house.and.flag")
                    .font(.system(size: 60)).foregroundStyle(.tint)
            }

            VStack(spacing: 4) {
                Text("galleRE").font(.largeTitle.bold())
                Text("Version \(appVersion)").font(.callout).foregroundStyle(.secondary)
                Text("Organize real-estate photos for the MLS.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Divider().padding(.horizontal, 40)

            VStack(spacing: 6) {
                Text("Created by **Clark Hess**")
                Text("Free & open source under the MIT License.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Link(destination: githubURL) {
                    Label("View source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)

                Link(destination: venmoURL) {
                    Label("Donate via Venmo  ·  @ClarkHess", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(.pink)

                Text("If galleRE saves you time, a tip is always appreciated 💜")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)

            Spacer(minLength: 0)

            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                .padding(.bottom, 4)
        }
        .padding(.top, 28)
        .frame(width: 400, height: 520)
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    private func loadBundledIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "galleRE", withExtension: "icns") {
            return NSImage(contentsOf: url)
        }
        return NSApplication.shared.applicationIconImage
    }
}
