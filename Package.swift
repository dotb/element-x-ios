// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Element Swift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "tools", targets: ["Tools"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.4.0")),
        .package(url: "https://github.com/element-hq/swift-command-line-tools.git", revision: "a6ad90808f4f6cac615ab8496c6ff1bc5f9fa192"),
        // .package(path: "../../../swift-command-line-tools"),
        .package(url: "https://github.com/jpsim/Yams", .upToNextMinor(from: "5.1.2"))
    ],
    targets: [
        .executableTarget(name: "Tools",
                          dependencies: [
                            .product(name: "ArgumentParser", package: "swift-argument-parser"),
                            .product(name: "CommandLineTools", package: "swift-command-line-tools"),
                            .product(name: "Yams", package: "Yams")
                          ],
                          path: "Tools/Sources")
    ]
)
