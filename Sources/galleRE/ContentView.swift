import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: PhotoStore
    @ObservedObject var settings = AppSettings.shared
    @State private var draggingID: UUID?
    @State private var selectedID: UUID?
    @State private var previewID: UUID?
    @State private var showPreview = false
    @State private var thumbScale: Double = 160
    @State private var showSettings = false
    @State private var showHelp = false
    @AppStorage("hasSeenHelp") private var hasSeenHelp = false

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbScale, maximum: thumbScale * 1.4), spacing: 12)]
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
            Divider()
            statusBar
        }
        .frame(minWidth: 720, minHeight: 520)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(store)
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .onAppear {
            if !hasSeenHelp {
                hasSeenHelp = true
                showHelp = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHelp)) { _ in
            showHelp = true
        }
        .overlay {
            if showPreview {
                PreviewView(currentID: $previewID, isPresented: $showPreview)
                    .environmentObject(store)
                    .transition(.opacity)
            }
        }
    }

    private func openPreview(_ id: UUID?) {
        guard let id else { return }
        selectedID = id
        previewID = id
        showPreview = true
    }

    private func moveSelection(_ delta: Int) {
        guard !store.items.isEmpty else { return }
        let current = store.items.firstIndex { $0.id == selectedID } ?? -1
        let next = min(max(current + delta, 0), store.items.count - 1)
        selectedID = store.items[next].id
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                pickFolder()
            } label: {
                Label("Open Folder", systemImage: "folder")
            }

            if store.folderURL != nil {
                Button {
                    store.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reload folder")

                Divider().frame(height: 20)

                Button {
                    store.applyOrderToFilenames()
                } label: {
                    Label("Save Current Order", systemImage: "textformat.123")
                }
                .help("Rename files in place so Finder keeps this order")
                .disabled(store.items.isEmpty || store.isBusy)

                Button {
                    Task { await store.exportOriginals() }
                } label: {
                    Label("Export Full-Size", systemImage: "square.and.arrow.up")
                }
                .help("Copy full-resolution photos, renamed in order, to the export subfolder")
                .disabled(store.items.isEmpty || store.isBusy)

                Button {
                    Task { await store.resizeAndExport() }
                } label: {
                    Label("Resize for MLS", systemImage: "arrow.down.right.and.arrow.up.left")
                }
                .help("Write downsized JPEGs (per Settings), renamed in order, to the export subfolder")
                .buttonStyle(.borderedProminent)
                .disabled(store.items.isEmpty || store.isBusy)
            }

            Spacer()

            if store.folderURL != nil {
                Slider(value: $thumbScale, in: 100...300) {}
                    .frame(width: 110)
                    .help("Thumbnail size")
            }

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")

            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .help("Help & tutorial")
        }
        .padding(10)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if store.folderURL == nil {
            emptyState
        } else if store.items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40)).foregroundStyle(.secondary)
                Text("No supported photos in this folder").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                        PhotoCell(item: item, order: index + 1, isSelected: selectedID == item.id)
                            .opacity(draggingID == item.id ? 0.35 : 1)
                            .onTapGesture(count: 2) { openPreview(item.id) }
                            .onTapGesture { selectedID = item.id }
                            .onDrag {
                                draggingID = item.id
                                selectedID = item.id
                                return NSItemProvider(object: item.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.text], delegate: ReorderDropDelegate(
                                item: item, store: store, draggingID: $draggingID))
                    }
                }
                .padding(14)
            }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.space) {
                openPreview(selectedID ?? store.items.first?.id)
                return .handled
            }
            .onKeyPress(.leftArrow)  { moveSelection(-1); return .handled }
            .onKeyPress(.rightArrow) { moveSelection(1);  return .handled }
            .onKeyPress(.return) {
                openPreview(selectedID ?? store.items.first?.id)
                return .handled
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "house.and.flag").font(.system(size: 52)).foregroundStyle(.secondary)
            Text("galleRE").font(.largeTitle.bold())
            Text("Open a folder of property photos to reorder, rename, and resize for MLS.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Folder…") { pickFolder() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Status bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            if store.isBusy { ProgressView().controlSize(.small) }
            Text(store.statusMessage).font(.callout).foregroundStyle(.secondary)
            Spacer()
            if let url = store.folderURL {
                Text(url.path).font(.caption).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    // MARK: Actions

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url {
            store.openFolder(url)
        }
    }
}

// MARK: - Photo cell

struct PhotoCell: View {
    @ObservedObject var item: PhotoItem
    let order: Int
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let img = item.thumbnail {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(.quaternary)
                            .overlay(ProgressView().controlSize(.small))
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(4.0/3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("\(order)")
                    .font(.caption.bold().monospacedDigit())
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(.black.opacity(0.65), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(6)
            }
            Text(item.fileName)
                .font(.caption2).lineLimit(1).truncationMode(.middle)
            Text("\(item.dimensionString)  ·  \(item.fileSizeString)")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor, lineWidth: isSelected ? 3 : 0)
        )
    }
}

// MARK: - Drop delegate for reorder

struct ReorderDropDelegate: DropDelegate {
    let item: PhotoItem
    let store: PhotoStore
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != item.id else { return }
        store.moveItem(id: draggingID, before: item.id)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
