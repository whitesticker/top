// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "top",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "top",
            path: "Sources/top"
        )
    ]
)
