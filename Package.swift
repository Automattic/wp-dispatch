// swift-tools-version:5.10
import PackageDescription

// The module can't be called "Dispatch": that's Apple's GCD module, and the name collides.
let package = Package(
    name: "Dispatch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "DispatchApp", path: "Sources/DispatchApp")
    ]
)
