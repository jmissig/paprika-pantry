// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "paprika-pantry",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "PantryKit",
            targets: ["PantryKit"]
        ),
        .executable(
            name: "paprika-pantry",
            targets: ["paprika-pantry"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "PantryKit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .executableTarget(
            name: "paprika-pantry",
            dependencies: ["PantryKit"]
        ),
        .testTarget(
            name: "PantryKitTests",
            dependencies: ["PantryKit"]
        ),
    ]
)
