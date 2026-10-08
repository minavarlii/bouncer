import Foundation

/// An app Bouncer is allowed to pause during calls.
struct Target: Identifiable, Hashable {
    /// Stable id used for settings.
    let id: String
    let name: String
    /// All bundle ids this app ships under (direct download vs App Store, etc.)
    let bundleIDs: Set<String>
}

enum Targets {
    static let all: [Target] = [
        Target(
            id: "dropbox",
            name: "Dropbox",
            bundleIDs: ["com.getdropbox.dropbox"]
        ),
        Target(
            id: "google-drive",
            name: "Google Drive",
            bundleIDs: ["com.google.drivefs"]
        ),
        Target(
            id: "onedrive",
            name: "OneDrive",
            bundleIDs: ["com.microsoft.OneDrive", "com.microsoft.OneDrive-mac"]
        ),
    ]

    static var allBundleIDs: Set<String> {
        all.reduce(into: Set<String>()) { $0.formUnion($1.bundleIDs) }
    }
}
