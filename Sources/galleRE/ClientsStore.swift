import SwiftUI

struct ClientFolder: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
    var name: String { url.lastPathComponent }

    /// Count of supported photo files directly inside the folder.
    var photoCount: Int {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return urls.filter { PhotoItem.supportedExtensions.contains($0.pathExtension.lowercased()) }.count
    }
}

@MainActor
final class ClientsStore: ObservableObject {
    static let archiveFolderName = "Archive"

    @AppStorage("clientsRootPath") private var rootPath: String = ""
    @Published var clients: [ClientFolder] = []
    @Published var archived: [ClientFolder] = []

    var rootURL: URL? { rootPath.isEmpty ? nil : URL(fileURLWithPath: rootPath) }
    var rootName: String { rootURL?.lastPathComponent ?? "" }

    func setRoot(_ url: URL) {
        rootPath = url.path
        refresh()
    }

    func clearRoot() {
        rootPath = ""
        clients = []
        archived = []
    }

    func refresh() {
        guard let root = rootURL,
              FileManager.default.fileExists(atPath: root.path) else {
            clients = []; archived = []; return
        }
        clients = folders(in: root, excluding: [Self.archiveFolderName])
        archived = folders(in: root.appendingPathComponent(Self.archiveFolderName), excluding: [])
    }

    private func folders(in dir: URL, excluding: Set<String>) -> [ClientFolder] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        else { return [] }
        return items
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { !excluding.contains($0.lastPathComponent) }
            .map { ClientFolder(url: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Archive / restore

    /// Move a client folder into <root>/Archive/.
    @discardableResult
    func archive(_ client: ClientFolder) -> Bool {
        guard let root = rootURL else { return false }
        let archiveDir = root.appendingPathComponent(Self.archiveFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)
        let dest = uniqueDestination(in: archiveDir, name: client.name)
        let ok = (try? FileManager.default.moveItem(at: client.url, to: dest)) != nil
        refresh()
        return ok
    }

    /// Move an archived client back to the root.
    @discardableResult
    func restore(_ client: ClientFolder) -> Bool {
        guard let root = rootURL else { return false }
        let dest = uniqueDestination(in: root, name: client.name)
        let ok = (try? FileManager.default.moveItem(at: client.url, to: dest)) != nil
        refresh()
        return ok
    }

    private func uniqueDestination(in dir: URL, name: String) -> URL {
        var dest = dir.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dest.path) {
            let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                .replacingOccurrences(of: "/", with: "-")
            dest = dir.appendingPathComponent("\(name) (\(stamp))")
            var n = 2
            while FileManager.default.fileExists(atPath: dest.path) {
                dest = dir.appendingPathComponent("\(name) (\(stamp)-\(n))"); n += 1
            }
        }
        return dest
    }
}
