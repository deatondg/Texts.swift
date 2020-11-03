// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Texts.swift",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "0.3.1")),
        .package(url: "https://github.com/kylef/PathKit", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/stencilproject/Stencil", .upToNextMajor(from: "0.14.0")),
        .package(url: "https://github.com/tuist/XcodeProj", .upToNextMajor(from: "7.17.0"))
    ],
    targets: [
        .target(
            name: "Texts.swift",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "PathKit",
                "Stencil",
                "XcodeProj",
            ],
            path: ".",
            sources: [
                "Sources",
                "Generated",
            ]),
    ]
)
