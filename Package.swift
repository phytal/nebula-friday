// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "NebulaTracker",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NebulaTracker", targets: ["NebulaTracker"])
    ],
    targets: [
        .executableTarget(
            name: "NebulaTracker",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)