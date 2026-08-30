import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: PhotoStore
    @EnvironmentObject var clients: ClientsStore
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedClient: URL?
    @State private var draggingID: UUID?
    @State private var selection: Set<UUID> = []
    @State private var anchorID: UUID?        // most recent click, for range-select & preview
    @State private var previewID: UUID?
    @State private var showPreview = false
    @State private var thumbScale: Double = 160
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var showExport = false
    @State private var showAbout = false
    @State private var showLimitEditor = false
    @State private var showDonation = false
    @AppStorage("hasSeenHelp") private var hasSeenHelp = false
    @AppStorage("dragHintDismissed") private var dragHintDismissed = false
    @AppStorage("launchCount") private var launchCount = 0
    static var launchCounted = false   // ensure we count once per process launch

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbScale, maximum: thumbScale * 1.4), spacing: 12)]
    }

    var body: some View {
        NavigationSplitView {
            ClientsSidebar(selectedClient: $selectedClient)
                .environmentObject(clients)
                .navigationSplitViewColumnWidth(min: 210, ideal: 250, max: 340)
        } detail: {
            mainContent
        }
        .frame(minWidth: 960, minHeight: 560)
        .onChange(of: selectedClient) { _, url in
            if let url { store.openFolder(url) }
        }
        .onAppear { clients.refresh() }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(store).environmentObject(clients)
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
        .sheet(isPresented: $showDonation) {
            DonationPromptView()
        }
        .onAppear {
            guard !Self.launchCounted else { return }
            Self.launchCounted = true
            launchCount += 1
            if !hasSeenHelp {
                hasSeenHelp = true
                showHelp = true
            } else if launchCount % 5 == 0 {
                // every 5th launch, thank the user and invite a donation
                showDonation = true
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

    private var mainContent: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
            Divider()
            statusBar
        }
    }

    private func openPreview(_ id: UUID?) {
        guard let id else { return }
        selectSingle(id)
        previewID = id
        showPreview = true
    }

    // MARK: Selection

    private func selectSingle(_ id: UUID) {
        selection = [id]; anchorID = id
    }
    private func toggle(_ id: UUID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        anchorID = id
    }
    private func selectRange(to id: UUID) {
        guard let anchor = anchorID,
              let a = store.items.firstIndex(where: { $0.id == anchor }),
              let b = store.items.firstIndex(where: { $0.id == id }) else { selectSingle(id); return }
        let lo = min(a, b), hi = max(a, b)
        selection = Set(store.items[lo...hi].map { $0.id })
    }
    private func selectAll() { selection = Set(store.items.map { $0.id }) }
    private func clearSelection() { selection = []; anchorID = nil }

    /// Items to act on for a bulk action: the selection, or the anchor if selection is empty.
    private var actionTargets: [PhotoItem] {
        if selection.isEmpty {
            return store.items.filter { $0.id == anchorID }
        }
        return store.items.filter { selection.contains($0.id) }
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
        let current = store.items.firstIndex { $0.id == anchorID } ?? -1
        let next = min(max(current + delta, 0), store.items.count - 1)
        selectSingle(store.items[next].id)
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
                    showExport = true
                } label: {
                    Label("Export…", systemImage: "square.and.arrow.up")
                }
                .help("Open the export wizard: resize, convert, rename and export")
                .buttonStyle(.borderedProminent)
                .tint(.brand)
                .disabled(store.includedCount == 0 || store.isBusy)
            }

            Spacer()

            if store.folderURL != nil {
                limitControl
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
        .background(Brand.barWash)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if store.folderURL == nil {
            emptyState
        } else {
          VStack(spacing: 0) {
            if store.navigationRoot != nil { breadcrumbBar }
            if !selection.isEmpty {
                selectionBar
            } else if !dragHintDismissed && store.items.count > 1 {
                dragHintBanner
            }

            if store.items.isEmpty && store.subfolders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("No photos or subfolders here").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                photoScroll
            }
          }
        }
    }

    private var photoScroll: some View {
        ScrollView {
            if !store.subfolders.isEmpty {
                foldersGrid
                if !store.items.isEmpty {
                    HStack { Text("Photos").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary); Spacer() }
                        .padding(.horizontal, 16).padding(.top, 4)
                }
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                    PhotoCell(item: item,
                              includedRank: includedRanks[item.id],
                              isOverLimit: isOverLimit(item),
                              isSelected: selection.contains(item.id),
                              store: store)
                        .opacity(draggingID == item.id ? 0.35 : 1)
                        .onTapGesture(count: 2) { openPreview(item.id) }
                        .highPriorityGesture(TapGesture().modifiers(.command).onEnded { toggle(item.id) })
                        .highPriorityGesture(TapGesture().modifiers(.shift).onEnded { selectRange(to: item.id) })
                        .onTapGesture { selectSingle(item.id) }
                        .onDrag {
                            draggingID = item.id
                            if !selection.contains(item.id) { selectSingle(item.id) }
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
            openPreview(anchorID ?? store.items.first?.id)
            return .handled
        }
        .onKeyPress(.leftArrow)  { moveSelection(-1); return .handled }
        .onKeyPress(.rightArrow) { moveSelection(1);  return .handled }
        .onKeyPress(.return) {
            openPreview(anchorID ?? store.items.first?.id)
            return .handled
        }
        .onKeyPress(.escape) { clearSelection(); return .handled }
        .onKeyPress(keys: ["a"]) { press in
            if press.modifiers.contains(.command) { selectAll(); return .handled }
            return .ignored
        }
    }

    private var foldersGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(store.subfolders, id: \.self) { url in
                FolderCell(url: url, photoCount: store.photoCount(in: url))
                    .onTapGesture { clearSelection(); store.enterFolder(url) }
            }
        }
        .padding(.horizontal, 14).padding(.top, 14)
    }

    private var breadcrumbBar: some View {
        HStack(spacing: 4) {
            Button {
                if let root = store.navigationRoot { clearSelection(); store.navigate(to: root) }
            } label: { Image(systemName: "house") }
            .buttonStyle(.borderless)
            .disabled(store.folderURL == store.navigationRoot)
            .help("Back to client root")

            ForEach(Array(store.breadcrumb.enumerated()), id: \.element) { idx, url in
                if idx > 0 { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }
                Button(url.lastPathComponent) {
                    clearSelection(); store.navigate(to: url)
                }
                .buttonStyle(.plain)
                .fontWeight(url == store.folderURL ? .semibold : .regular)
                .foregroundStyle(url == store.folderURL ? Color.primary : Color.secondary)
            }
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Brand.barWash)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: Selection / bulk-action bar

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text("\(selection.count) selected").font(.callout.weight(.semibold))
            Divider().frame(height: 18)
            Button { store.setWatermark(ids: selection, on: true) } label: {
                Label("Watermark", systemImage: "textformat.size")
            }
            Button { store.setWatermark(ids: selection, on: false) } label: {
                Label("Remove WM", systemImage: "textformat.size.smaller")
            }
            Divider().frame(height: 18)
            Button { store.setIncluded(ids: selection, on: true) } label: {
                Label("Include", systemImage: "eye.fill")
            }
            Button { store.setIncluded(ids: selection, on: false) } label: {
                Label("Exclude", systemImage: "eye.slash.fill")
            }
            Spacer()
            Button("Select All") { selectAll() }
            Button { clearSelection() } label: { Label("Done", systemImage: "xmark.circle.fill") }
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Brand.gradient.opacity(0.14))
        .overlay(alignment: .bottom) { Divider() }
    }

    // Clickable MLS-limit control: a pill when a limit is set, else a subtle "Set limit" chip.
    @ViewBuilder
    private var limitControl: some View {
        Button { showLimitEditor = true } label: {
            if settings.maxPhotos > 0 { countPillLabel } else {
                Label("Set MLS limit", systemImage: "number")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showLimitEditor, arrowEdge: .bottom) { limitEditor }
    }

    private var limitEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MLS photo limit").font(.headline)
            HStack {
                Stepper(value: $settings.maxPhotos, in: 0...200) {
                    Text(settings.maxPhotos == 0 ? "No limit" : "\(settings.maxPhotos) photos")
                        .monospacedDigit()
                }
            }
            HStack(spacing: 6) {
                ForEach([0, 24, 25, 36, 50], id: \.self) { n in
                    Button(n == 0 ? "None" : "\(n)") { settings.maxPhotos = n }
                        .buttonStyle(.bordered).controlSize(.small)
                        .tint(settings.maxPhotos == n ? .brand : nil)
                }
            }
            if settings.maxPhotos > 0 && store.includedCount > settings.maxPhotos {
                Divider()
                Button {
                    store.trimToLimit(); showLimitEditor = false
                } label: {
                    Label("Trim to \(settings.maxPhotos) (exclude \(store.includedCount - settings.maxPhotos))",
                          systemImage: "scissors")
                }
                .buttonStyle(.borderedProminent).tint(.orange)
            }
            Text("Common MLS caps are 24–50. The pill shows your included count vs. this limit.")
                .font(.caption).foregroundStyle(.secondary).frame(width: 240)
        }
        .padding(16)
    }

    @ViewBuilder
    private var countPillLabel: some View {
        let count = store.includedCount
        let max = settings.maxPhotos
        let over = count > max
        HStack(spacing: 8) {
            Image(systemName: over ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text("\(count) / \(max)").monospacedDigit()
            if over { Image(systemName: "chevron.down").font(.caption2) }
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(over ? .orange : .green)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background((over ? Color.orange : Color.green).opacity(0.12), in: Capsule())
        .help(over ? "\(count - max) over the MLS limit of \(max) — click to adjust or trim" : "Within the MLS limit of \(max) — click to change")
    }

    private var dragHintBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw.fill")
                .foregroundStyle(Color.brand)
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
        .background(Brand.violet.opacity(0.10))
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
            selectedClient = nil   // ad-hoc folder, not a client selection
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
                .strokeBorder(isSelected ? Color.brand : (isOverLimit ? Color.orange : .clear),
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

// MARK: - Folder cell (navigable subfolder)

struct FolderCell: View {
    let url: URL
    let photoCount: Int
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Brand.violet.opacity(hovering ? 0.18 : 0.10))
                Image(systemName: "folder.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Brand.accent)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(4.0/3.0, contentMode: .fit)

            Text(url.lastPathComponent)
                .font(.caption2).lineLimit(1).truncationMode(.middle)
            Text(photoCount > 0 ? "\(photoCount) photo\(photoCount == 1 ? "" : "s")" : "Open")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .help("Open “\(url.lastPathComponent)”")
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
