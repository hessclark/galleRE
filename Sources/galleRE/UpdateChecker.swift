import SwiftUI

/// Checks GitHub Releases on launch and flags when a newer version is available.
@MainActor
final class UpdateChecker: ObservableObject {
    @Published var latestVersion: String?   // set only when newer than the running version

    let downloadURL = URL(string: "https://github.com/hessclark/galleRE/releases/latest/download/galleRE.dmg")!
    let releasesURL = URL(string: "https://github.com/hessclark/galleRE/releases/latest")!

    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    func check() {
        guard let api = URL(string: "https://api.github.com/repos/hessclark/galleRE/releases/latest") else { return }
        var req = URLRequest(url: api, timeoutInterval: 10)
        req.setValue("galleRE-app", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            let remote = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            Task { @MainActor in
                guard let self else { return }
                if Self.isNewer(remote, than: self.currentVersion) {
                    self.latestVersion = remote
                }
            }
        }.resume()
    }

    /// Numeric, component-wise semantic-version comparison (1.2 vs 1.10 handled correctly).
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
