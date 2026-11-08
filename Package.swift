// swift-tools-version: 6.2

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
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.12.0"),
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
