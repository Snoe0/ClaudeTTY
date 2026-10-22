// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeTTY",
    platforms: [.macOS("26.0")],
    targets: [
        .binaryTarget(name: "GhosttyKit", path: "GhosttyKit.xcframework"),
        .executableTarget(
            name: "ClaudeTTY",
            dependencies: ["GhosttyKit"],
            linkerSettings: [.linkedLibrary("c++"), .linkedFramework("Carbon"), .linkedFramework("Metal"), .linkedFramework("QuartzCore"), .linkedFramework("IOSurface")]),
    ]
)
