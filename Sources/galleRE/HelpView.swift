import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        .init(icon: "folder",
              title: "Open a folder",
              detail: "Thumbnails load in a grid — JPEG, PNG, HEIC, TIFF and PDF."),
        .init(icon: "hand.draw",
              title: "Drag to reorder",
              detail: "The number badge shows each photo's MLS position. Press Space to preview."),
        .init(icon: "textformat.123",
              title: "Save Current Order",
              detail: "Renames files in place so Finder and the MLS keep your order."),
        .init(icon: "eye.slash",
              title: "Fit your MLS limit",
              detail: "Set a max photo count in Settings, then use the eye toggle on any thumbnail to include/exclude — a counter and “Trim” help you hit the number."),
        .init(icon: "textformat.size",
              title: "Watermark (optional)",
              detail: "Toggle a text watermark on any photo (e.g. “virtually staged / edited with AI”). It's burned in only on export — originals stay clean."),
        .init(icon: "square.and.arrow.up",
              title: "Export…",
              detail: "One wizard: resize for MLS or keep full-res, convert PDFs/HEIC to JPG, and rename — copies go to a subfolder, originals untouched."),
    ]

    // App-icon gradient, reused as the screen's accent.
    private let iconGradient = LinearGradient(
        colors: [Color(red: 96/255, green: 129/255, blue: 1),
                 Color(red: 124/255, green: 92/255, blue: 234/255),
                 Color(red: 99/255, green: 70/255, blue: 220/255)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 13) {
                            Image(systemName: step.icon)
                                .font(.title3)
                                .frame(width: 34, height: 34)
                                .background(iconGradient.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                                .foregroundStyle(Color(red: 108/255, green: 82/255, blue: 226/255))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title).font(.headline)
                                Text(step.detail).font(.callout).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    creditCard
                }
                .padding(18)
            }
            Divider()
            HStack {
                Spacer()
                Button("Get Started") { dismiss() }
                    .keyboardShortcut(.defaultAction).controlSize(.large)
            }
            .padding()
        }
        .frame(width: 500, height: 560)
    }

    private var header: some View {
        HStack(spacing: 14) {
            appIcon
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text("Welcome to galleRE").font(.title2.bold())
                Text("The best way to organize, optimize, and manage your real estate MLS photos.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
    }

    /// The real app icon if available, otherwise a drawn stand-in in the same style.
    @ViewBuilder
    private var appIcon: some View {
        if let url = Bundle.main.url(forResource: "galleRE", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            Image(nsImage: img).resizable()
        } else {
            ZStack {
                iconGradient
                Image(systemName: "house.fill").foregroundStyle(.white).font(.system(size: 26))
            }
        }
    }

    private var creditCard: some View {
        VStack(spacing: 10) {
            Text("Created by Clark Hess · free & open source (MIT)")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Link(destination: Support.venmoURL) {
                    Label("Donate · @ClarkHess", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(.pink)
                Link(destination: Support.githubURL) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .buttonStyle(.bordered)
                Button { Support.reportBug() } label: {
                    Label("Report a Bug", systemImage: "ladybug")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(iconGradient.opacity(0.08)))
        .padding(.top, 6)
    }
}
