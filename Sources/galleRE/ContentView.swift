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
    @State private var showExport = false
    @State private var showAbout = false
    @AppStorage("hasSeenHelp") private var hasSeenHelp = false
    @AppStorage("dragHintDismissed") private var dragHintDismissed = false

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
        .sheet(isPresented: $showExport) {
            ExportWizardView().environmentObject(store)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
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
        .onReceive(NotificationCenter.default.publisher(for: .showAbout)) { _ in
            showAbout = true
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

    // Rank among included photos (1-based); nil for excluded.
    private var includedRanks: [UUID: Int] {
        var rank = 0
        var map: [UUID: Int] = [:]
        for it in store.items where it.included { rank += 1; map[it.id] = rank }
        return map
    }

    private func isOverLimit(_ item: PhotoItem) -> Bool {
        let max = settings.maxPhotos
        guard max > 0, let r = includedRanks[item.id] else { return false }
        return r > max
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
                    if let id = selectedID, let item = store.items.first(where: { $0.id == id }) {
                        store.toggleWatermark(item)
                    }
                } label: {
                    Label("Watermark", systemImage: "textformat.size")
                }
                .help("Toggle the watermark on the selected photo (configure text in Settings)")
                .disabled(selectedID == nil || store.isBusy)

                Button {
                    showExport = true
                } label: {
                    Label("Export…", systemImage: "square.and.arrow.up")
                }
                .help("Open the export wizard: resize, convert, rename and export")
                .buttonStyle(.borderedProminent)
                .disabled(store.includedCount == 0 || store.isBusy)
            }

            Spacer()

            if store.folderURL != nil, settings.maxPhotos > 0 {
                countPill
            }

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
          VStack(spacing: 0) {
            if !dragHintDismissed && store.items.count > 1 {
                dragHintBanner
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                        PhotoCell(item: item,
                                  includedRank: includedRanks[item.id],
                                  isOverLimit: isOverLimit(item),
                                  isSelected: selectedID == item.id,
                                  store: store)
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
    }

    @ViewBuilder
    private var countPill: some View {
        let count = store.includedCount
        let max = settings.maxPhotos
        let over = count > max
        HStack(spacing: 8) {
            Image(systemName: over ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text("\(count) / \(max)").monospacedDigit()
            if over {
                Button("Trim") { store.trimToLimit() }
                    .buttonStyle(.borderedProminent).controlSize(.small).tint(.orange)
                    .help("Exclude photos beyond the MLS limit")
            }
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(over ? .orange : .green)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background((over ? Color.orange : Color.green).opacity(0.12), in: Capsule())
        .help(over ? "\(count - max) over the MLS limit of \(max)" : "Within the MLS limit of \(max)")
    }

    private var dragHintBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw.fill")
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating)
            Text("Drag any photo to reorder. The number badge shows its MLS position — then click **Save Current Order** to lock it in.")
                .font(.callout)
            Spacer()
            Button {
                withAnimation { dragHintDismissed = true }
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.tint.opacity(0.10))
        .overlay(alignment: .bottom) { Divider() }
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
    var includedRank: Int?          // position among included photos; nil if excluded
    var isOverLimit: Bool = false
    var isSelected: Bool = false
    let store: PhotoStore
    @State private var hovering = false

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
                .saturation(item.included ? 1 : 0)
                .opacity(item.included ? 1 : 0.55)

                // Order badge (or an excluded marker)
                orderBadge.padding(6)

                // Watermark tag (persistent when on)
                if item.watermarked {
                    Label("Watermark", systemImage: "textformat.size")
                        .font(.system(size: 9, weight: .bold))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.blue.opacity(0.85), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }

                // Hover controls: include toggle + watermark toggle
                HStack(spacing: 6) {
                    cellButton(item.included ? "eye.fill" : "eye.slash.fill",
                               tip: item.included ? "Exclude from MLS set" : "Include in MLS set") {
                        store.toggleIncluded(item)
                    }
                    cellButton(item.watermarked ? "textformat.size" : "textformat",
                               active: item.watermarked,
                               tip: item.watermarked ? "Remove watermark" : "Add watermark") {
                        store.toggleWatermark(item)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .opacity(hovering ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: hovering)
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
                .strokeBorder(isSelected ? Color.accentColor : (isOverLimit ? Color.orange : .clear),
                              lineWidth: (isSelected || isOverLimit) ? 3 : 0)
        )
        .onHover { h in
            hovering = h
            if h { NSCursor.openHand.push() } else { NSCursor.pop() }
        }
    }

    @ViewBuilder
    private var orderBadge: some View {
        if let rank = includedRank {
            Text("\(rank)")
                .font(.caption.bold().monospacedDigit())
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background((isOverLimit ? Color.orange : .black.opacity(0.65)), in: Capsule())
                .foregroundStyle(.white)
        } else {
            Image(systemName: "eye.slash.fill")
                .font(.caption2.bold())
                .padding(5)
                .background(.black.opacity(0.55), in: Circle())
                .foregroundStyle(.white)
        }
    }

    private func cellButton(_ symbol: String, active: Bool = false, tip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 26, height: 26)
                .background((active ? Color.blue : .black.opacity(0.55)), in: Circle())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .help(tip)
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
