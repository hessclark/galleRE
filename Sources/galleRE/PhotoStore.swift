import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PhotoStore: ObservableObject {
    @Published var folderURL: URL?
    @Published var items: [PhotoItem] = []
    @Published var subfolders: [URL] = []
    @Published var navigationRoot: URL?   // the top-level folder opened; breadcrumb stops here
    @Published var isBusy = false
    @Published var statusMessage = ""

    private let settings = AppSettings.shared

    // MARK: - Loading & navigation

    /// Open a top-level folder (a client or an ad-hoc pick). Resets the breadcrumb root here.
    func openFolder(_ url: URL) {
        navigationRoot = url
        folderURL = url
        reload()
    }

    /// Drill into a subfolder, keeping the current breadcrumb root.
    func enterFolder(_ url: URL) {
        folderURL = url
        reload()
    }

    /// Jump to any folder between the root and the current one (breadcrumb click).
    func navigate(to url: URL) {
        folderURL = url
        reload()
    }

    /// Breadcrumb trail from navigationRoot down to the current folder.
    var breadcrumb: [URL] {
        guard let root = navigationRoot, let current = folderURL else { return [] }
        var trail: [URL] = []
        var cur: URL? = current
        while let c = cur, c.path.hasPrefix(root.path) {
            trail.insert(c, at: 0)
            if c.path == root.path { break }
            cur = c.deletingLastPathComponent()
        }
        return trail
    }

    func reload() {
        guard let folderURL else { return }
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: folderURL,
                                                includingPropertiesForKeys: [.isDirectoryKey],
                                                options: [.skipsHiddenFiles])) ?? []
        // Subfolders (excluding the export subfolder), so nested photo folders are navigable.
        subfolders = urls
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { $0.lastPathComponent != settings.exportFolderName }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        let photos = urls
            .filter { PhotoItem.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { PhotoItem(url: $0) }
        items = photos
        for p in photos { p.loadThumbnail() }

        let photoPart = "\(photos.count) photo\(photos.count == 1 ? "" : "s")"
        let folderPart = subfolders.isEmpty ? "" : " · \(subfolders.count) folder\(subfolders.count == 1 ? "" : "s")"
        statusMessage = photoPart + folderPart
    }

    /// Count of supported photos directly inside a folder (for folder cards).
    func photoCount(in url: URL) -> Int {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return urls.filter { PhotoItem.supportedExtensions.contains($0.pathExtension.lowercased()) }.count
    }

    // MARK: - Reordering

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    func moveItem(id: UUID, before targetID: UUID) {
        guard let from = items.firstIndex(where: { $0.id == id }),
              var to = items.firstIndex(where: { $0.id == targetID }) else { return }
        if from < to { to -= 1 }
        let item = items.remove(at: from)
        items.insert(item, at: max(0, min(to, items.count)))
    }

    // MARK: - Renaming to preserve order in Finder

    /// Rename every file in place so the on-disk name reflects the current order.
    func applyOrderToFilenames() {
        guard let folderURL else { return }
        isBusy = true
        defer { isBusy = false }
        let fm = FileManager.default
        let total = items.filter { $0.included }.count

        // Two-phase to avoid collisions: rename to temp names, then to finals.
        // Included photos are numbered in order; excluded photos get an "x_" prefix.
        var tempMap: [(item: PhotoItem, finalName: String)] = []
        var includedRank = 0
        for item in items {
            let ext = item.url.pathExtension
            let originalBase = item.url.deletingPathExtension().lastPathComponent
            let cleanedBase = stripLeadingNumber(from: originalBase)
            let base: String
            if item.included {
                includedRank += 1
                base = settings.fileBaseName(order: includedRank,
                                             originalBaseName: cleanedBase,
                                             totalCount: total)
            } else {
                base = "x_" + cleanedBase
            }
            let finalName = ext.isEmpty ? base : "\(base).\(ext)"
            tempMap.append((item, finalName))
        }

        // phase 1
        var tempURLs: [URL] = []
        for (i, entry) in tempMap.enumerated() {
            let tmp = folderURL.appendingPathComponent(".gallere_tmp_\(i)_\(entry.finalName)")
            try? fm.moveItem(at: entry.item.url, to: tmp)
            tempURLs.append(tmp)
        }
        // phase 2
        for (i, entry) in tempMap.enumerated() {
            let dest = folderURL.appendingPathComponent(entry.finalName)
            // guard against an unrelated existing file with the target name
            if fm.fileExists(atPath: dest.path) && dest != tempURLs[i] {
                try? fm.removeItem(at: dest)
            }
            try? fm.moveItem(at: tempURLs[i], to: dest)
            entry.item.url = dest
        }
        statusMessage = "Renamed \(total) file\(total == 1 ? "" : "s") to match order"
    }

    private func stripLeadingNumber(from base: String) -> String {
        // remove a prior "x_" exclude prefix, then patterns like "01_", "001-", "12 "
        var s = base
        if s.hasPrefix("x_") { s = String(s.dropFirst(2)) }
        let pattern = "^\\d+[\\s_\\-]+"
        if let range = s.range(of: pattern, options: .regularExpression) {
            return String(s[range.upperBound...])
        }
        return s
    }

    // MARK: - Include / exclude helpers

    var includedCount: Int { items.filter { $0.included }.count }

    func toggleIncluded(_ item: PhotoItem) { item.included.toggle(); objectWillChange.send() }
    func toggleWatermark(_ item: PhotoItem) { item.watermarked.toggle(); objectWillChange.send() }
    func setWatermarkAll(_ on: Bool) { items.forEach { $0.watermarked = on }; objectWillChange.send() }
    func setIncludedAll(_ on: Bool) { items.forEach { $0.included = on }; objectWillChange.send() }
    func setWatermark(ids: Set<UUID>, on: Bool) { items.filter { ids.contains($0.id) }.forEach { $0.watermarked = on }; objectWillChange.send() }
    func setIncluded(ids: Set<UUID>, on: Bool) { items.filter { ids.contains($0.id) }.forEach { $0.included = on }; objectWillChange.send() }

    /// Exclude every included photo ranked beyond the MLS max (0 = no limit).
    func trimToLimit() {
        let max = settings.maxPhotos
        guard max > 0 else { return }
        var rank = 0
        for item in items where item.included {
            rank += 1
            if rank > max { item.included = false }
        }
        statusMessage = "Trimmed to \(min(rank, max)) photo\(max == 1 ? "" : "s") (MLS limit \(max))"
        objectWillChange.send()
    }

    // MARK: - Export (resize)

    struct ExportOptions {
        var resize: Bool          // true = downscale to MLS target; false = full resolution
        var convertToJPG: Bool    // for full-res raster: re-encode to JPG (PDFs always convert)
    }

    @Published var lastExportDir: URL?

    /// Run an export using the given options. Settings (dimensions, naming, folder) come from AppSettings.
    func export(options: ExportOptions) async {
        guard let folderURL, !items.isEmpty else { return }
        isBusy = true
        let verb = options.resize ? "Resizing" : "Exporting"
        statusMessage = "\(verb)…"
        let settings = self.settings
        // Only included photos are exported, renumbered among themselves.
        let snapshot = items.filter { $0.included }
        let outputDir = folderURL.appendingPathComponent(settings.exportFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        lastExportDir = outputDir

        // If renaming in place, rename originals first so both stay in sync.
        if settings.outputMode == .inPlace {
            applyOrderToFilenames()
        }

        let total = snapshot.count
        let resize = options.resize
        let convert = options.convertToJPG
        var savedBytes = 0
        var fileCount = 0
        var done = 0

        await Task.detached(priority: .userInitiated) {
            for (idx, item) in snapshot.enumerated() {
                let originalBase = item.url.deletingPathExtension().lastPathComponent
                let cleaned = originalBase.replacingOccurrences(of: "^\\d+[\\s_\\-]+", with: "", options: .regularExpression)
                let base = settings.fileBaseName(order: idx + 1, originalBaseName: cleaned, totalCount: total)
                let mark = item.watermarked

                if ImageProcessor.isPDF(item.url) {
                    // Rasterize each PDF page to its own JPG (page suffix only when multi-page).
                    let pages = max(1, ImageProcessor.pdfPageCount(item.url))
                    for p in 1...pages {
                        let suffix = pages > 1 ? "_p\(p)" : ""
                        let dest = outputDir.appendingPathComponent("\(base)\(suffix).jpg")
                        if let result = try? ImageProcessor.processPDFPage(
                            source: item.url, page: p, destURL: dest, settings: settings, resize: resize, watermark: mark) {
                            savedBytes += (p == 1 ? result.originalBytes : 0) - result.newBytes
                            fileCount += 1
                        }
                    }
                } else if resize {
                    let dest = outputDir.appendingPathComponent("\(base).jpg")
                    if let result = try? ImageProcessor.process(source: item.url, destURL: dest, settings: settings, watermark: mark) {
                        savedBytes += (result.originalBytes - result.newBytes)
                        fileCount += 1
                    }
                } else if convert || mark {
                    // full resolution, re-encoded to JPG (forced when watermarking a raster copy)
                    let dest = outputDir.appendingPathComponent("\(base).jpg")
                    if let result = try? ImageProcessor.processFullSizeJPEG(
                        source: item.url, destURL: dest, quality: settings.jpegQuality, settings: settings, watermark: mark) {
                        savedBytes += (result.originalBytes - result.newBytes)
                        fileCount += 1
                    }
                } else {
                    // full-size copy, keeping the original extension
                    let ext = item.url.pathExtension.isEmpty ? "jpg" : item.url.pathExtension
                    let dest = outputDir.appendingPathComponent("\(base).\(ext)")
                    try? FileManager.default.removeItem(at: dest)
                    if (try? FileManager.default.copyItem(at: item.url, to: dest)) != nil {
                        fileCount += 1
                    }
                }
                done += 1
                let d = done
                await MainActor.run { self.statusMessage = "\(verb) \(d)/\(total)…" }
            }
        }.value

        if resize {
            let saved = ByteCountFormatter.string(fromByteCount: Int64(max(0, savedBytes)), countStyle: .file)
            statusMessage = "Exported \(fileCount) file\(fileCount == 1 ? "" : "s") to \(settings.exportFolderName)  ·  saved \(saved)"
        } else {
            statusMessage = "Exported \(fileCount) file\(fileCount == 1 ? "" : "s") to \(settings.exportFolderName)"
        }
        isBusy = false
    }

    func revealExportFolder() {
        guard let folderURL else { return }
        let dir = folderURL.appendingPathComponent(settings.exportFolderName)
        if FileManager.default.fileExists(atPath: dir.path) {
            NSWorkspace.shared.open(dir)
        }
    }
}
