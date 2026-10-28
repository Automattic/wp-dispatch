// swift-tools-version:5.10
import PackageDescription

// The module can't be called "Dispatch": that's Apple's GCD module, and the name collides.
let package = Package(
    name: "Dispatch",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "DispatchApp",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/DispatchApp",
            // build.sh copies Sparkle.framework into Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
    ]
)
