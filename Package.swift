// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "WPNotifications",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "WPNotifications", path: "Sources/WPNotifications")
    ]
)
