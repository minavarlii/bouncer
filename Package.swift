// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Bouncer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Bouncer",
            path: "Sources/Bouncer"
        )
    ]
)
