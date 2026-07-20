// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LumenMediaCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "LumenMediaCore", targets: ["LumenMediaCore"]),
    ],
    targets: [
        .target(
            name: "LumenMediaCore",
            path: "Sources/LumenMediaCore"
        ),
        .testTarget(
            name: "LumenMediaCoreTests",
            dependencies: ["LumenMediaCore"],
            path: "Tests/LumenMediaCoreTests"
        ),
    ]
)
