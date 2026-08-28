import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PhotoStore: ObservableObject {
    @Published var folderURL: URL?
    @Published var items: [PhotoItem] = []
    @Published var isBusy = false
    @Published var statusMessage = ""

    private let settings = AppSettings.shared

    // MARK: - Loading

    func openFolder(_ url: URL) {
        folderURL = url
        reload()
    }

    func reload() {
        guard let folderURL else { return }
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: folderURL,
                                                includingPropertiesForKeys: nil,
                                                options: [.skipsHiddenFiles])) ?? []
        let photos = urls
            .filter { PhotoItem.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { PhotoItem(url: $0) }
        items = photos
        for p in photos { p.loadThumbnail() }
        statusMessage = "\(photos.count) photo\(photos.count == 1 ? "" : "s")"
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
        let total = items.count

        // Two-phase to avoid collisions: rename to temp names, then to finals.
        var tempMap: [(item: PhotoItem, finalName: String)] = []
        for (idx, item) in items.enumerated() {
            let ext = item.url.pathExtension
            let originalBase = item.url.deletingPathExtension().lastPathComponent
            // strip any existing leading number prefix like "01_" to avoid stacking
            let cleanedBase = stripLeadingNumber(from: originalBase)
            let base = settings.fileBaseName(order: idx + 1,
                                             originalBaseName: cleanedBase,
                                             totalCount: total)
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
        // remove patterns like "01_", "001-", "12 " at the very start
        let pattern = "^\\d+[\\s_\\-]+"
        if let range = base.range(of: pattern, options: .regularExpression) {
            return String(base[range.upperBound...])
        }
        return base
    }

    // MARK: - Export (resize)

    /// Resize to the MLS target and write renamed copies to the export subfolder.
    func resizeAndExport() async {
        await runExport(resize: true, verb: "Resizing")
    }

    /// Write full-resolution renamed copies to the export subfolder (no downscaling).
    func exportOriginals() async {
        await runExport(resize: false, verb: "Exporting")
    }

    private func runExport(resize: Bool, verb: String) async {
        guard let folderURL, !items.isEmpty else { return }
        isBusy = true
        statusMessage = "\(verb)…"
        let settings = self.settings
        let snapshot = items
        let outputDir = folderURL.appendingPathComponent(settings.exportFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // If renaming in place, rename originals first so both stay in sync.
        if settings.outputMode == .inPlace {
            applyOrderToFilenames()
        }

        let total = snapshot.count
        var savedBytes = 0
        var done = 0

        await Task.detached(priority: .userInitiated) {
            for (idx, item) in snapshot.enumerated() {
                let originalBase = item.url.deletingPathExtension().lastPathComponent
                let cleaned = originalBase.replacingOccurrences(of: "^\\d+[\\s_\\-]+", with: "", options: .regularExpression)
                let base = settings.fileBaseName(order: idx + 1, originalBaseName: cleaned, totalCount: total)

                if ImageProcessor.isPDF(item.url) {
                    // Rasterize each PDF page to its own JPG (page suffix only when multi-page).
                    let pages = max(1, ImageProcessor.pdfPageCount(item.url))
                    for p in 1...pages {
                        let suffix = pages > 1 ? "_p\(p)" : ""
                        let dest = outputDir.appendingPathComponent("\(base)\(suffix).jpg")
                        if let result = try? ImageProcessor.processPDFPage(
                            source: item.url, page: p, destURL: dest, settings: settings, resize: resize) {
                            // count the source size only once, on the first page
                            savedBytes += (p == 1 ? result.originalBytes : 0) - result.newBytes
                        }
                    }
                } else if resize {
                    let dest = outputDir.appendingPathComponent("\(base).jpg")
                    if let result = try? ImageProcessor.process(source: item.url, destURL: dest, settings: settings) {
                        savedBytes += (result.originalBytes - result.newBytes)
                    }
                } else {
                    // full-size copy, keeping the original extension
                    let ext = item.url.pathExtension.isEmpty ? "jpg" : item.url.pathExtension
                    let dest = outputDir.appendingPathComponent("\(base).\(ext)")
                    try? FileManager.default.removeItem(at: dest)
                    try? FileManager.default.copyItem(at: item.url, to: dest)
                }
                done += 1
                let d = done
                await MainActor.run {
                    self.statusMessage = "\(verb) \(d)/\(total)…"
                }
            }
        }.value

        if resize {
            let saved = ByteCountFormatter.string(fromByteCount: Int64(max(0, savedBytes)), countStyle: .file)
            statusMessage = "Resized \(total) photo\(total == 1 ? "" : "s") to \(settings.exportFolderName)  (saved \(saved))"
        } else {
            statusMessage = "Exported \(total) full-size photo\(total == 1 ? "" : "s") to \(settings.exportFolderName)"
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
