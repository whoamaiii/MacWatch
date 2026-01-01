// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clarity",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ClarityDaemon", targets: ["ClarityDaemon"]),
        .executable(name: "ClarityApp", targets: ["ClarityApp"]),
        .library(name: "ClarityShared", targets: ["ClarityShared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.24.0"),
    ],
    targets: [
        .target(
            name: "ClarityShared",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/ClarityShared"
        ),
        .executableTarget(
            name: "ClarityDaemon",
            dependencies: ["ClarityShared"],
            path: "Sources/ClarityDaemon"
        ),
        .executableTarget(
            name: "ClarityApp",
            dependencies: ["ClarityShared"],
            path: "Sources/ClarityApp"
        ),
        .testTarget(
            name: "ClarityTests",
            dependencies: ["ClarityShared"],
            path: "Tests/ClarityTests"
        ),
    ]
)
