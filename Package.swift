// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeLauncher",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeLauncher",
            dependencies: ["HotKey"]
        ),
    ]
)
