import AppKit

/// Shared links and the "Report a Bug" flow.
enum Support {
    static let repo = "https://github.com/hessclark/galleRE"
    static let githubURL = URL(string: repo)!
    static let venmoURL  = URL(string: "https://venmo.com/u/ClarkHess")!

    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    /// Opens a new GitHub issue with a pre-filled bug-report template.
    static func reportBug() {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        let body = """
        **Describe the bug**
        <!-- What went wrong? -->


        **Steps to reproduce**
        1.
        2.

        **What I expected**


        **What actually happened**


        ---
        galleRE version: \(appVersion)
        macOS: \(osVersion)
        """

        var comps = URLComponents(string: "\(repo)/issues/new")!
        comps.queryItems = [
            URLQueryItem(name: "title", value: "[Bug] "),
            URLQueryItem(name: "labels", value: "bug"),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = comps.url {
            NSWorkspace.shared.open(url)
        }
    }
}
