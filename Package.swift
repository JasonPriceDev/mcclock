// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "McClock",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "McClock", targets: ["McClock"])],
    targets: [
        .executableTarget(name: "McClock"),
        .testTarget(name: "McClockTests", dependencies: ["McClock"]),
    ]
)
