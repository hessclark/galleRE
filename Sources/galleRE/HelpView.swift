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
              title: "1 · Open a folder",
              detail: "Click Open Folder and choose the folder of property photos. JPEG, PNG, HEIC, TIFF and PDF files all appear in the grid (PDFs show their first page), each with its dimensions and size."),
        .init(icon: "hand.draw",
              title: "2 · Drag to reorder",
              detail: "Drag any thumbnail to a new spot. The number badge on each photo updates live to show the current MLS order."),
        .init(icon: "eye",
              title: "3 · Preview a photo",
              detail: "Click a photo to select it, then press Space (or double-click) for a large preview. Use ← / → to flip through, Space or Esc to close."),
        .init(icon: "textformat.123",
              title: "4 · Save Current Order",
              detail: "Renames the files in place with number prefixes so Finder — and the MLS uploader — keeps your exact order. Uses safe two-phase renaming."),
        .init(icon: "arrow.down.right.and.arrow.up.left",
              title: "5 · Resize for MLS",
              detail: "Writes downsized JPEGs (per your Settings, default long edge 1024px) into an export subfolder, renamed in order. HEIC, PNG and PDF files are converted to JPG automatically; multi-page PDFs become one JPG per page. Originals stay untouched."),
        .init(icon: "square.and.arrow.up",
              title: "Export Full-Size",
              detail: "Need full-resolution copies too? This writes renamed, full-size files to the export subfolder — great for brochures or archives."),
        .init(icon: "gearshape",
              title: "Settings",
              detail: "Change the naming scheme, resize target (long edge or max file size), JPEG quality, and where exports go. A live preview shows the resulting filename."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "house.and.flag")
                    .font(.title).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to galleRE").font(.title2.bold())
                    Text("Organize, order, and resize real-estate photos for the MLS.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: step.icon)
                                .font(.title3)
                                .frame(width: 34, height: 34)
                                .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title).font(.headline)
                                Text(step.detail).font(.callout).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Divider().padding(.vertical, 4)
                    Text("Tip: your originals are never modified by resizing — exports always go to a separate subfolder. \"Save Current Order\" is the only action that renames files in place.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
            }

            Divider()
            HStack {
                Spacer()
                Button("Get Started") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding()
        }
        .frame(width: 520, height: 620)
    }
}
